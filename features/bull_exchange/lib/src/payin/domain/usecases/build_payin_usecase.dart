import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_answers.dart';
import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:sync/sync.dart' show BitcoinTx, decodeLiquidPset;

/// Liquid's network minimum relay fee (0.1 sat/vByte = 25 sat/kwu).
const _liquidFeeRate = RelativeFee(25);

/// Builds the wallet's payin to the order's deposit. An on-chain payin is
/// built as its [PayinSpendOptions] say (the fee, replace-by-fee and coins
/// picked on the review); it is prepared for payjoin, unsigned, when the
/// user kept payjoin on, the order published a payjoin URI and enough of
/// the order's window is left for a negotiation to finish; otherwise it is
/// signed. Nothing is sent.
class BuildPayinUsecase {
  final Spend _spend;

  const BuildPayinUsecase(this._spend);

  Future<Result<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>> execute(
    PayinBuild<PayinSpend> effect,
  ) async {
    final amountSat = (effect.order.payinAmount * 100000000).round();
    return switch (effect.target) {
      OnchainDeposit(:final address) => _buildBitcoin(
        effect,
        address,
        amountSat,
      ),
      LiquidDeposit(:final address) => _buildLiquid(effect, address, amountSat),
      // No app wallet pays a Lightning invoice (BitcoinRail.canBeAppWallet).
      LightningInvoiceDeposit() => const Err(
        ExchangePayinBuildFailure(PayinBuildProblem.invalid),
      ),
    };
  }

  Future<Result<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>>
  _buildBitcoin(
    PayinBuild<PayinSpend> effect,
    String address,
    int amountSat,
  ) async {
    final options = effect.spend.options;
    final fee = networkFeeOf(options.fee);
    final PreparedBitcoinSpend prepared;
    switch (await _spend.prepareBitcoin(
      walletId: effect.walletId,
      recipients: [
        BitcoinTransactionRecipient.fixed(
          address: address,
          amountSat: Sats.fromInt(amountSat),
        ),
      ],
      networkFee: fee,
      selectedInputs: options.coins.isEmpty ? null : options.coins,
      replaceByFee: options.replaceByFee,
    )) {
      case Ok(:final value):
        prepared = value;
      case Err(:final failure):
        return Err(ExchangePayinBuildFailure(payinBuildProblemOf(failure)));
    }
    final bip21 = effect.order.payjoinBip21;
    final deadline = effect.order.confirmationDeadline;
    final window = bip21 == null || deadline == null
        ? null
        : PayjoinSessionWindow.forOrderDeadline(deadline, now: clock.now());
    if (bip21 != null && window != null && options.payjoin) {
      final String txid;
      try {
        txid = (await BitcoinTx.fromPsbt(prepared.unsignedPsbt)).txid;
      } on Object {
        return const Err(
          ExchangePayinBuildFailure(PayinBuildProblem.unexpected),
        );
      }
      return Ok(
        PayinBuilt(
          effect.spend,
          txid,
          PayjoinPayin<PreparedBitcoinSpend>(
            prepared: prepared,
            bip21: bip21,
            amountSat: amountSat,
            feeRateSatPerVb: fee.isRelative
                ? fee.value.toDouble()
                : prepared.fee.value.toInt() / prepared.txSize,
            expiresAt: clock.now().add(window),
          ),
        ),
      );
    }
    switch (await _spend.signBitcoin(prepared: prepared)) {
      case Ok(value: final signed):
        final txid = await _txidOfSigned(signed);
        if (txid == null) {
          return const Err(
            ExchangePayinBuildFailure(PayinBuildProblem.unexpected),
          );
        }
        return Ok(
          PayinBuilt(
            effect.spend,
            txid,
            SignedBitcoinPayin<SignedBitcoinSpend>(signed),
          ),
        );
      case Err(:final failure):
        return Err(ExchangePayinBuildFailure(payinBuildProblemOf(failure)));
    }
  }

  Future<Result<PayinBuilt<PayinSpend>, ExchangePayinBuildFailure>>
  _buildLiquid(
    PayinBuild<PayinSpend> effect,
    String address,
    int amountSat,
  ) async {
    final PreparedLiquidSpend prepared;
    switch (await _spend.prepareLiquid(
      walletId: effect.walletId,
      address: address,
      feeRate: _liquidFeeRate,
      amountSat: amountSat,
    )) {
      case Ok(:final value):
        prepared = value;
      case Err(:final failure):
        return Err(ExchangePayinBuildFailure(payinBuildProblemOf(failure)));
    }
    switch (await _spend.signLiquid(prepared: prepared)) {
      case Ok(value: final signed):
        return switch (decodeLiquidPset(signed.signedPset)) {
          Ok(value: final decoded) => Ok(
            PayinBuilt(
              effect.spend,
              decoded.txid,
              SignedLiquidPayin<SignedLiquidSpend>(signed),
            ),
          ),
          Err() => const Err(
            ExchangePayinBuildFailure(PayinBuildProblem.unexpected),
          ),
        };
      case Err(:final failure):
        return Err(ExchangePayinBuildFailure(payinBuildProblemOf(failure)));
    }
  }
}

/// The txid of the signed transaction itself (SELL-12: not the unsigned
/// PSBT's, which differs for inputs whose signature is in the scriptSig).
Future<String?> _txidOfSigned(SignedBitcoinSpend signed) async {
  final raw = signed.signedTransaction.trim();
  try {
    if (raw.startsWith('cHNid')) return (await BitcoinTx.fromPsbt(raw)).txid;
    return (await BitcoinTx.fromBytes(_hexBytes(raw))).txid;
  } on Object {
    return null;
  }
}

List<int> _hexBytes(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];
