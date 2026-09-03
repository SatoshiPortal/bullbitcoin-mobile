import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// What the confirmation screen needs to price a payin before the order exists.
typedef PayPayinFeeEstimate = ({
  double exchangeRateEstimate,
  int requiredAmountSat,
  int absoluteFees,
  FeeOptions? bitcoinFees,
  int? bitcoinTxSize,
});

/// Prices the payin for [wallet] against a throwaway address, so the wallet
/// screen can show a fee before an order is placed.
///
/// Owns the balance check too: a wallet that cannot cover the amount is a
/// modelled failure, not a string. It used to be reported as an unexpected
/// failure carrying the hardcoded English "Insufficient balance. Required: N
/// sats", which reached the screen untranslated.
class EstimatePayPayinFeesUsecase {
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final PreparePayBitcoinPayinUsecase _preparePayBitcoinPayinUsecase;
  final PreparePayLiquidPayinUsecase _preparePayLiquidPayinUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  const EstimatePayPayinFeesUsecase({
    required this._convertSatsToCurrencyAmountUsecase,
    required this._getAddressAtIndexUsecase,
    required this._getNetworkFeesUsecase,
    required this._preparePayBitcoinPayinUsecase,
    required this._preparePayLiquidPayinUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
  });

  /// 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
  static const _liquidEstimateFeeRate = RelativeFee(25);

  @useResult
  Future<Result<PayPayinFeeEstimate, PayFailure>> execute({
    required Wallet wallet,
    required double fiatAmount,
    required String currencyCode,
  }) async {
    final double exchangeRateEstimate;
    final String throwawayAddress;
    try {
      exchangeRateEstimate = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: currencyCode,
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the exchange rate for the pay payin estimate',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }

    final requiredAmountSat = ConvertAmount.fiatToSats(
      fiatAmount,
      exchangeRateEstimate,
    );

    if (wallet.balanceSat.toInt() < requiredAmountSat) {
      log.info('Pay wallet ${wallet.id} cannot cover $requiredAmountSat sats');
      return Err(
        PayInsufficientBalanceFailure(requiredAmountSat: requiredAmountSat),
      );
    }

    try {
      final address = await _getAddressAtIndexUsecase.execute(
        walletId: wallet.id,
        index: 0,
      );
      throwawayAddress = address.address;
    } catch (e, st) {
      log.severe(
        message: 'Failed to derive the pay fee-estimation address',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }

    if (wallet.isLiquid) {
      final String pset;
      switch (await _preparePayLiquidPayinUsecase.execute(
        walletId: wallet.id,
        address: throwawayAddress,
        amountSat: requiredAmountSat,
        feeRate: _liquidEstimateFeeRate,
      )) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          pset = value;
      }

      try {
        final absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
        return Ok((
          exchangeRateEstimate: exchangeRateEstimate,
          requiredAmountSat: requiredAmountSat,
          absoluteFees: absoluteFees,
          bitcoinFees: null,
          bitcoinTxSize: null,
        ));
      } catch (e, st) {
        log.severe(
          message: 'Failed to read the absolute fees of a pay payin PSET',
          error: e,
          trace: st,
        );
        return Err(PayUnexpectedFailure('$e'));
      }
    }

    final FeeOptions bitcoinFees;
    try {
      bitcoinFees = await _getNetworkFeesUsecase.execute(isLiquid: false);
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the network fees for the pay payin estimate',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }

    // Fastest is the default selection, so the estimate shown on arrival is the
    // estimate for the tier the payin would be built at.
    final PreparedPayBitcoinPayin payin;
    switch (await _preparePayBitcoinPayinUsecase.execute(
      walletId: wallet.id,
      address: throwawayAddress,
      amountSat: requiredAmountSat,
      networkFee: bitcoinFees.fastest,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        payin = value;
    }

    try {
      final absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
        psbt: payin.unsignedPsbt,
      );
      return Ok((
        exchangeRateEstimate: exchangeRateEstimate,
        requiredAmountSat: requiredAmountSat,
        absoluteFees: absoluteFees,
        bitcoinFees: bitcoinFees,
        bitcoinTxSize: payin.txSize,
      ));
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the absolute fees of a pay payin PSBT',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
