import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Sell's boundary onto the shared read-only core use-cases.
class LoadSellContextUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final IndexPriceReader _getIndexPrice;
  final GetOrderUsecase _getOrderUsecase;

  const LoadSellContextUsecase({
    required this._getExchangeUserSummaryUsecase,
    required this._getSettingsUsecase,
    required this._getNetworkFeesUsecase,
    required this._getAddressAtIndexUsecase,
    required this._getIndexPrice,
    required this._getOrderUsecase,
  });

  /// The exchange account summary and the app settings, which the sell screen
  /// needs together before it can show anything.
  @useResult
  Future<
    Result<({UserSummary userSummary, SettingsEntity settings}), SellFailure>
  >
  userSummaryAndSettings() async {
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      final settings = await _getSettingsUsecase.execute();
      return Ok((userSummary: userSummary, settings: settings));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the exchange user summary or settings',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<FeeOptions, SellFailure>> networkFees({
    required bool isLiquid,
  }) async {
    try {
      return Ok(await _getNetworkFeesUsecase.execute(isLiquid: isLiquid));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the network fees',
        error: e,
        trace: st,
      );
      return Err(SellFeesUnavailableFailure('$e'));
    }
  }

  /// An address of the user's own wallet, used only as a stand-in when
  /// estimating fees before the real payin address is known.
  @useResult
  Future<Result<WalletAddress, SellFailure>> addressAtIndex({
    required String walletId,
    required int index,
  }) async {
    try {
      return Ok(
        await _getAddressAtIndexUsecase.execute(
          walletId: walletId,
          index: index,
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to derive a wallet address for the fee estimate',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }

  /// [amountSat] in [currencyCode], or in the settings currency when none is
  /// given. Without an amount, the price of one bitcoin.
  @useResult
  Future<Result<double, SellFailure>> satsToCurrency({
    BigInt? amountSat,
    String? currencyCode,
  }) async {
    final SettingsEntity settings;
    try {
      settings = await _getSettingsUsecase.execute();
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the sell price',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
    final code = currencyCode ?? settings.currencyCode;
    final currency = SupportedCurrency.tryFromCode(code);
    if (currency == null) {
      return Err(SellUnexpectedFailure('Currency not available: $code'));
    }
    final price = await _getIndexPrice(
      network: settings.environment.isTestnet
          ? BitcoinNetwork.testnet
          : BitcoinNetwork.mainnet,
      currency: currency,
    );
    switch (price) {
      case Ok(:final value):
        return Ok(
          value.fiatValueOf(
            amountSat ?? ConversionConstants.satsAmountOfOneBitcoin,
          ),
        );
      // Without a price there is no estimate: a zero rate would need zero
      // sats and pass any balance check.
      case Err(:final failure):
        log.warning('Sell price unavailable: ${failure.runtimeType}');
        return Err(SellQuoteUnavailableFailure(failure.logMessage));
    }
  }

  @useResult
  Future<Result<Order, SellFailure>> order({required String orderId}) async {
    try {
      return Ok(await _getOrderUsecase.execute(orderId: orderId));
    } catch (e, st) {
      log.severe(message: 'Failed to load the sell order', error: e, trace: st);
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}
