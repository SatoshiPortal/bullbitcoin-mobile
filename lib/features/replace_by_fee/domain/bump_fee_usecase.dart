import 'package:bb_mobile/features/send/public/broadcast_failure.dart'
    show WalletSpendBlockedException;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show BitcoinSpendStatus;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    as wallet
    show Network, NetworkX;
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:bb_mobile/features/send/public/send_setup.dart'
    show BitcoinWalletRepository;
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:sync/sync.dart'
    show
        SignatureCheck,
        SyncBusyFailure,
        SyncFailure,
        SyncFeeRateTooLowFailure,
        SyncOriginalSignaturesFailure,
        SyncSpendBlockedFailure,
        UnsignedSpend;
import 'package:meta/meta.dart';

class BumpFeeUsecase {
  final BitcoinWalletRepository _bitcoinWalletRepository;
  final BroadcastBitcoinTransactionUsecase _broadcastBitcoinTransactionUsecase;
  final Fees _fees;
  final Preferences _preferences;

  BumpFeeUsecase({
    required this._bitcoinWalletRepository,
    required this._broadcastBitcoinTransactionUsecase,
    required this._fees,
    required this._preferences,
  });

  @useResult
  Future<Result<FeeOptions, ReplaceByFeeFailure>> getNetworkFees() async {
    try {
      final SettingsEntity settings;
      switch (await _preferences.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err(:final failure):
          final reason = 'Preferences read failed: ${failure.runtimeType}';
          log.warning(reason);
          return const Err(ReplaceByFeeNetworkFeesFailure());
      }
      final network = wallet.Network.fromEnvironment(
        environment: settings.environment.networkEnv,
        isLiquid: false,
      );
      switch (await _fees.estimate(network.shared)) {
        case Ok(:final value):
          return Ok(value);
        case Err(:final failure):
          final reason =
              'Network fee estimation unavailable: ${failure.runtimeType}';
          log.warning(reason);
          return const Err(ReplaceByFeeNetworkFeesFailure());
      }
    } on Exception catch (e, st) {
      log.warning('Failed to fetch network fees for RBF', error: e, trace: st);
      return const Err(ReplaceByFeeNetworkFeesFailure());
    }
  }

  /// Pre-flight check for the RBF screen: refuses to offer a bump when the
  /// original transaction's signatures don't verify (a planted transaction,
  /// GHSA-6jp4-8v48-cc5v). [execute] re-runs the same check fail-closed.
  @useResult
  Future<Result<void, ReplaceByFeeFailure>> verifyOriginalTransaction({
    required String walletId,
    required String txid,
  }) async {
    try {
      final status = await _bitcoinWalletRepository
          .getTransactionSignatureStatus(walletId: walletId, txid: txid);
      return switch (status) {
        SignatureCheck.valid => const Ok(null),
        SignatureCheck.invalid => const Err(
          ReplaceByFeeManipulatedTransactionFailure(),
        ),
        SignatureCheck.unverifiable => const Err(
          ReplaceByFeeUnverifiableTransactionFailure(),
        ),
      };
    } catch (e, st) {
      log.severe(
        message: 'Failed to verify original transaction for RBF',
        error: e,
        trace: st,
      );
      return Err(ReplaceByFeeUnexpectedFailure(e.toString()));
    }
  }

  /// Builds the replacement in sync's writer, signs it with `secrets`, then
  /// broadcasts it with the generation it was built at.
  @useResult
  Future<Result<String, ReplaceByFeeFailure>> execute({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
    required Network network,
  }) async {
    try {
      final built = await _bitcoinWalletRepository.bumpFee(
        walletId: walletId,
        txid: txid,
        newFeeRate: newFeeRate,
      );
      final UnsignedSpend unsigned;
      switch (built) {
        case Ok(:final value):
          unsigned = value;
        case Err(:final failure):
          return Err(_bumpFailure(failure));
      }
      final signed = await _bitcoinWalletRepository.signPsbt(
        unsigned.encoded,
        walletId: walletId,
      );
      final broadcastedTxid = await _broadcastBitcoinTransactionUsecase.execute(
        signed,
        isPsbt: true,
        network: network,
        walletId: walletId,
        built: unsigned,
      );
      return Ok(broadcastedTxid);
    } on WalletSpendBlockedException catch (e) {
      return Err(
        ReplaceByFeeSpendBlockedFailure(
          replacementPending: e.status == BitcoinSpendStatus.replacementPending,
          busy: e.status == BitcoinSpendStatus.busy,
        ),
      );
    } catch (e, st) {
      log.severe(message: 'Bump fee failed', error: e, trace: st);
      return Err(ReplaceByFeeUnexpectedFailure(e.toString()));
    }
  }

  static ReplaceByFeeFailure _bumpFailure(SyncFailure failure) {
    switch (failure) {
      case SyncOriginalSignaturesFailure(check: SignatureCheck.invalid):
        log.severe(
          message: 'Refused to bump a transaction with invalid signatures',
          error: 'original_signatures',
          trace: StackTrace.current,
        );
        return const ReplaceByFeeManipulatedTransactionFailure();
      case SyncOriginalSignaturesFailure():
        log.warning(
          'Refused to bump a transaction whose signatures could not be verified',
        );
        return const ReplaceByFeeUnverifiableTransactionFailure();
      case SyncFeeRateTooLowFailure():
        log.warning('Replacement fee rate below the original');
        return const ReplaceByFeeFeeRateTooLowFailure();
      case SyncSpendBlockedFailure(:final status):
        return ReplaceByFeeSpendBlockedFailure(
          replacementPending: status == BitcoinSpendStatus.replacementPending,
          busy: false,
        );
      case SyncBusyFailure():
        return const ReplaceByFeeSpendBlockedFailure(
          replacementPending: false,
          busy: true,
        );
      case _:
        log.warning('Bump fee refused category=${failure.logCode}');
        return ReplaceByFeeUnexpectedFailure(failure.logCode);
    }
  }
}
