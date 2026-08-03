import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:meta/meta.dart';

/// Estimates the on-chain payin cost of selling from [wallet] before the sell
/// order is created: fetches the exchange rate, derives the required amount,
/// enforces the sufficient-balance rule, and computes the absolute network fee
/// by building a throwaway transaction to a wallet-owned address.

class EstimateSellPayinFeesUsecase {
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  EstimateSellPayinFeesUsecase({
    required this._convertSatsToCurrencyAmountUsecase,
    required this._getAddressAtIndexUsecase,
    required this._getNetworkFeesUsecase,
    required this._prepareBitcoinSendUsecase,
    required this._prepareLiquidSendUsecase,
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
  });

  @useResult
  Future<Result<({int absoluteFees, double exchangeRateEstimate}), SellFailure>>
  execute({
    required Wallet wallet,
    required OrderAmount orderAmount,
    required FiatCurrency fiatCurrency,
  }) async {
    try {
      final exchangeRateEstimate = await _convertSatsToCurrencyAmountUsecase
          .execute(currencyCode: fiatCurrency.code);

      final int requiredAmountSat;
      if (orderAmount.isFiat) {
        requiredAmountSat = ConvertAmount.fiatToSats(
          orderAmount.amount,
          exchangeRateEstimate,
        );
      } else {
        requiredAmountSat = ConvertAmount.btcToSats(orderAmount.amount);
      }

      if (wallet.balanceSat.toInt() < requiredAmountSat) {
        return Err(
          SellInsufficientBalanceFailure(requiredAmountSat: requiredAmountSat),
        );
      }

      final dummyAddressForFeeCalculation = await _getAddressAtIndexUsecase
          .execute(walletId: wallet.id, index: 0);

      final int absoluteFees;
      if (wallet.isLiquid) {
        final pset = await _prepareLiquidSendUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          // 0.1 sat/vByte = 25 sat/kwu — Liquid's network minrelayfee default.
          feeRate: const RelativeFee(25),
        );
        absoluteFees = await _calculateLiquidAbsoluteFeesUsecase.execute(
          pset: pset,
        );
      } else {
        final bitcoinFees = await _getNetworkFeesUsecase.execute(
          isLiquid: false,
        );
        final preparedSend = await _prepareBitcoinSendUsecase.execute(
          walletId: wallet.id,
          address: dummyAddressForFeeCalculation.address,
          amountSat: requiredAmountSat,
          networkFee: bitcoinFees.fastest,
        );
        absoluteFees = await _calculateBitcoinAbsoluteFeesUsecase.execute(
          psbt: preparedSend.unsignedPsbt,
        );
      }

      return Ok((
        absoluteFees: absoluteFees,
        exchangeRateEstimate: exchangeRateEstimate,
      ));
    } catch (e, st) {
      log.severe(message: 'sell fee estimation failed', error: e, trace: st);
      return Err(SellPrepareTransactionFailure(e.toString()));
    }
  }
}
