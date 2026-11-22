import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    as wallet
    show Network, NetworkX;
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadBuyContextUsecase {
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final Preferences _getSettingsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final Fees _fees;
  final IndexPriceReader _getIndexPrice;

  const LoadBuyContextUsecase({
    required this._getExchangeUserSummaryUsecase,
    required this._getSettingsUsecase,
    required this._getWalletsUsecase,
    required this._getReceiveAddressUsecase,
    required this._fees,
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
      final settings = (await _getSettingsUsecase.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
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
      final SettingsEntity settings;
      switch (await _getSettingsUsecase.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err(:final failure):
          final reason = 'Preferences read failed: ${failure.runtimeType}';
          log.warning(reason);
          return Err(BuyUnexpectedFailure(reason));
      }
      final network = wallet.Network.fromEnvironment(
        environment: settings.environment.networkEnv,
        isLiquid: isLiquid,
      );
      switch (await _fees.estimate(network.shared)) {
        case Ok(:final value):
          return Ok(value);
        case Err(:final failure):
          final reason =
              'Network fee estimation unavailable: ${failure.runtimeType}';
          log.warning(reason);
          return Err(BuyUnexpectedFailure(reason));
      }
    } on Exception catch (e, st) {
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
      settings = (await _getSettingsUsecase.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
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
