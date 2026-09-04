import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/pay/domain/calculate_pay_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_payin_address_usecase.dart';
import 'package:bb_mobile/features/pay/domain/load_pay_network_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
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
  /// 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
  static const _liquidEstimateFeeRate = RelativeFee(25);

  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetPayPayinAddressUsecase _getPayPayinAddressUsecase;
  final LoadPayNetworkFeesUsecase _loadPayNetworkFeesUsecase;
  final PreparePayBitcoinPayinUsecase _preparePayBitcoinPayinUsecase;
  final PreparePayLiquidPayinUsecase _preparePayLiquidPayinUsecase;
  final CalculatePayAbsoluteFeesUsecase _calculatePayAbsoluteFeesUsecase;

  const EstimatePayPayinFeesUsecase({
    required this._convertSatsToCurrencyAmountUsecase,
    required this._getPayPayinAddressUsecase,
    required this._loadPayNetworkFeesUsecase,
    required this._preparePayBitcoinPayinUsecase,
    required this._preparePayLiquidPayinUsecase,
    required this._calculatePayAbsoluteFeesUsecase,
  });

  @useResult
  Future<Result<PayPayinFeeEstimate, PayFailure>> execute({
    required Wallet wallet,
    required double fiatAmount,
    required String currencyCode,
  }) async {
    final double exchangeRateEstimate;
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

    final String throwawayAddress;
    switch (await _getPayPayinAddressUsecase.execute(walletId: wallet.id)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        throwawayAddress = value;
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

      switch (await _calculatePayAbsoluteFeesUsecase.liquid(pset: pset)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          return Ok((
            exchangeRateEstimate: exchangeRateEstimate,
            requiredAmountSat: requiredAmountSat,
            absoluteFees: value,
            bitcoinFees: null,
            bitcoinTxSize: null,
          ));
      }
    }

    final FeeOptions bitcoinFees;
    switch (await _loadPayNetworkFeesUsecase.execute(isLiquid: false)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        bitcoinFees = value;
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

    switch (await _calculatePayAbsoluteFeesUsecase.bitcoin(
      psbt: payin.unsignedPsbt,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return Ok((
          exchangeRateEstimate: exchangeRateEstimate,
          requiredAmountSat: requiredAmountSat,
          absoluteFees: value,
          bitcoinFees: bitcoinFees,
          bitcoinTxSize: payin.txSize,
        ));
    }
  }
}
