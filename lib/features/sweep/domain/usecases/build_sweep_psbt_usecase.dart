import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_quote.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Outpoint;

/// Builds the unsigned sweep and reads the real fee back off the PSBT.
///
/// Owns the one invariant the SDK cannot enforce for us: a frozen or
/// payjoin-reserved coin must never become an input. BDK gives manually pinned
/// utxos priority over its unspendable list, so the check has to happen here,
/// before the outpoints are handed down — and it **refuses** rather than
/// quietly dropping the coin, because dropping one would change the total the
/// user just allocated without them seeing it.
class BuildSweepPsbtUsecase {
  final BitcoinSendPort _bitcoinSend;
  final WalletUtxoRepository _walletUtxoRepository;
  final PayjoinSessions _payjoin;

  BuildSweepPsbtUsecase({
    required BitcoinSendPort bitcoinSendPort,
    required this._walletUtxoRepository,
    required PayjoinSessions payjoinSessions,
  }) : _bitcoinSend = bitcoinSendPort,
       _payjoin = payjoinSessions;

  @useResult
  Future<Result<SweepQuote, SweepFailure>> execute({
    required String walletId,
    required SweepPlan plan,
    required NetworkFee networkFee,
    int? floorSatPerKwu,
  }) async {
    final unspendable = await _unspendableOutpoints();
    switch (unspendable) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final blocked = plan.outpoints.where(value.contains).length;
        if (blocked > 0) {
          log.warning(
            'Refusing to sweep: $blocked of ${plan.outpoints.length} selected '
            'coins are frozen or payjoin-reserved',
          );
          return Err(SweepUnspendableInputFailure(blocked));
        }
    }

    try {
      final psbt = await _bitcoinSend.buildSweepPsbt(
        walletId: walletId,
        recipients: plan.recipients,
        inputs: plan.inputs,
        networkFee: networkFee,
      );
      final txSize = await _bitcoinSend.getTxSize(psbt: psbt);
      final feeSat = await _bitcoinSend.getTxFeeAmount(psbt: psbt);
      final clearsRelay = networkFee is RelativeFee
          ? networkFee.aboveMinRelay(floorSatPerKwu: floorSatPerKwu)
          : NetworkFee.absolute(
              feeSat,
            ).aboveMinRelay(txSize: txSize, floorSatPerKwu: floorSatPerKwu);
      if (floorSatPerKwu != null && !clearsRelay) {
        log.warning(
          'Refusing sweep PSBT below relay floor: $feeSat sats at '
          '$txSize vbytes',
        );
        return const Err(SweepFeeTooLowFailure());
      }

      return Ok(
        SweepQuote(
          plan: plan,
          networkFee: networkFee,
          unsignedPsbt: psbt,
          txSize: txSize,
          feeSat: BigInt.from(feeSat),
        ),
      );
    } on bdk.InsufficientFundsCreateTxException catch (e) {
      // Reachable whenever the fee no longer fits: `manuallySelectedOnly`
      // stops BDK from topping the tx up with another coin, which is exactly
      // the behaviour a sweep wants.
      return Err(
        SweepInsufficientFundsFailure(BigInt.from(e.needed - e.available)),
      );
    } on bdk.CoinSelectionCreateTxException catch (e) {
      // Same user-visible situation as above, reported through a different
      // variant: BDK raises this one when the *selection* cannot cover the
      // outputs plus the fee. It carries prose rather than numbers, hence the
      // tolerant parse below — a format change degrades the message, never the
      // classification.
      return Err(
        SweepInsufficientFundsFailure(
          _shortfallFromMessage(e.errorMessage),
          e.errorMessage,
        ),
      );
    } on bdk.OutputBelowDustLimitCreateTxException catch (e) {
      // The SDK is the authority on dust. Quote the threshold of the output it
      // actually rejected rather than a generic number, so the figure shown
      // matches the address the user typed.
      final index = e.index;
      final rejected = index >= 0 && index < plan.recipients.length
          ? plan.recipients[index].address
          : null;
      log.warning('Sweep output $index is below the dust limit');
      return Err(
        SweepAmountBelowDustFailure(
          rejected == null
              ? SweepPlan.minimumOutputSat
              : SweepPlan.minimumOutputSatFor(rejected),
        ),
      );
    } on bdk.FeeRateTooLowCreateTxException {
      return const Err(SweepFeeTooLowFailure());
    } on bdk.FeeTooLowCreateTxException {
      return const Err(SweepFeeTooLowFailure());
    } on Exception catch (e, st) {
      log.severe(message: 'Failed to build sweep psbt', error: e, trace: st);
      return Err(SweepBuildFailure(e.toString()));
    }
  }

  /// Pulls the shortfall out of BDK's coin-selection message so the user is
  /// told *how much* is missing rather than just "it failed".
  ///
  /// The message is upstream prose — currently
  /// `Insufficient funds: 0.00001188 BTC available of 0.00001242 BTC needed` —
  /// so this is deliberately tolerant: no match simply means no number to show,
  /// never a wrong one. The amounts are converted through [BigInt] by shifting
  /// the decimal point, never through [double], so a satoshi cannot be lost to
  /// binary rounding.
  static BigInt? _shortfallFromMessage(String message) {
    final match = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)\s*BTC\s+available\s+of\s+'
      r'([0-9]+(?:\.[0-9]+)?)\s*BTC\s+needed',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;

    final available = _btcStringToSats(match.group(1)!);
    final needed = _btcStringToSats(match.group(2)!);
    if (available == null || needed == null) return null;

    final shortfall = needed - available;
    return shortfall > BigInt.zero ? shortfall : null;
  }

  /// Exact decimal-BTC → satoshi conversion (8 decimal places).
  static BigInt? _btcStringToSats(String btc) {
    final parts = btc.split('.');
    if (parts.length > 2) return null;
    final whole = parts.first;
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > 8) return null;
    final padded = fraction.padRight(8, '0');
    return BigInt.tryParse('$whole$padded');
  }

  /// Every outpoint that must not be spent: user-frozen ∪ payjoin-reserved.
  Future<Result<Set<Outpoint>, SweepFailure>> _unspendableOutpoints() async {
    try {
      final frozen = await _walletUtxoRepository.getAllFrozenOutpoints();
      final reserved = await _payjoin.reservedOutpoints();

      return switch (reserved) {
        Ok(:final value) => Ok({...frozen, ...value}),
        Err(:final failure) => Err(
          SweepBuildFailure(
            'Failed to read payjoin-reserved outpoints: '
            '${failure.runtimeType}',
          ),
        ),
      };
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to read the unspendable outpoint set',
        error: e,
        trace: st,
      );
      return Err(SweepBuildFailure(e.toString()));
    }
  }
}
