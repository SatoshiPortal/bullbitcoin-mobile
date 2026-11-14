import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadBuyContextUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final IndexPriceReader _getIndexPrice;

  const LoadBuyContextUsecase({
    required this._getExchangeUserSummaryUsecase,
    required this._getSettingsUsecase,
    required this._getWalletsUsecase,
    required this._getReceiveAddressUsecase,
    required this._getNetworkFeesUsecase,
    required this._getIndexPrice,
  });

  /// The exchange account summary and the app settings, which the buy screen
  /// needs together before it can show anything.
  @useResult
  Future<
    Result<({UserSummary userSummary, SettingsEntity settings}), BuyFailure>
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
      return Err(BuyUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<List<Wallet>, BuyFailure>> wallets() async {
    final result = await _getWalletsUsecase.execute();
    if (result case Err(:final failure)) {
      log.warning('Failed to load the wallets: ${failure.logMessage}');
    }
    return result.mapErr(
      (failure) => BuyUnexpectedFailure('wallets: ${failure.runtimeType}'),
    );
  }

  /// The address the exchange will pay out to.
  @useResult
  Future<Result<WalletAddress, BuyFailure>> receiveAddress({
    required String walletId,
  }) async {
    try {
      return Ok(await _getReceiveAddressUsecase.execute(walletId: walletId));
    } catch (e, st) {
      log.severe(
        message: 'Failed to derive the buy payout address',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<FeeOptions, BuyFailure>> networkFees({
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
      return Err(BuyUnexpectedFailure('$e'));
    }
  }

  /// [amountSat] in [currencyCode], or in the settings currency when none is
  /// given. Without an amount, the price of one bitcoin.
  @useResult
  Future<Result<double, BuyFailure>> satsToCurrency({
    BigInt? amountSat,
    String? currencyCode,
  }) async {
    final SettingsEntity settings;
    try {
      settings = await _getSettingsUsecase.execute();
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the buy price',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
    final code = currencyCode ?? settings.currencyCode;
    final currency = SupportedCurrency.tryFromCode(code);
    if (currency == null) {
      return Err(BuyUnexpectedFailure('Currency not available: $code'));
    }
    final price = await _getIndexPrice(
      network: switch (settings.environment) {
        Environment.mainnet => BitcoinNetwork.mainnet,
        Environment.testnet => BitcoinNetwork.testnet,
        Environment.regtest => BitcoinNetwork.regtest,
      },
      currency: currency,
    );
    switch (price) {
      case Ok(:final value):
        return Ok(
          value.fiatValueOf(
            amountSat ?? ConversionConstants.satsAmountOfOneBitcoin,
          ),
        );
      case Err(:final failure):
        log.warning('Buy price unavailable: ${failure.runtimeType}');
        return Err(BuyQuoteUnavailableFailure(failure.logMessage));
    }
  }
}
