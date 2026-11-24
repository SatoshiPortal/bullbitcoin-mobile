import 'package:bull_exchange/src/payin/payin_account.dart';
import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/payin/payin_constants.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Sell's boundary onto the shared read-only core use-cases.
class LoadSellContextUsecase {
  final PayinAccount _account;
  final Preferences _getSettingsUsecase;
  final Fees _fees;
  final PayinWallets _wallets;
  final IndexPriceReader _getIndexPrice;

  const LoadSellContextUsecase({
    required this._account,
    required this._getSettingsUsecase,
    required this._fees,
    required this._wallets,
    required this._getIndexPrice,
  });

  /// The exchange account summary and the app settings, which the sell screen
  /// needs together before it can show anything.
  @useResult
  Future<
    Result<({UserSummary userSummary, SettingsEntity settings}), SellFailure>
  >
  userSummaryAndSettings() async => (await _account.summary()).mapErr(
    (failure) =>
        SellUnexpectedFailure('Summary unavailable: ${failure.runtimeType}'),
  );

  @useResult
  Future<Result<FeeOptions, SellFailure>> networkFees({
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
          return Err(SellFeesUnavailableFailure(reason));
      }
      final Network network = isLiquid
          ? LiquidNetwork.fromName(settings.environment.name)
          : BitcoinNetwork.fromName(settings.environment.name);
      switch (await _fees.estimate(network)) {
        case Ok(:final value):
          return Ok(value);
        case Err(:final failure):
          final reason =
              'Network fee estimation unavailable: ${failure.runtimeType}';
          log.warning(reason);
          return Err(SellFeesUnavailableFailure(reason));
      }
    } on Exception catch (e, st) {
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
  Future<Result<String, SellFailure>> addressAtIndex({
    required WalletKey walletKey,
    required int index,
  }) async => (await _wallets.addressAt(walletKey, index)).mapErr(
    (failure) =>
        SellUnexpectedFailure('Fee address unavailable: ${failure.logCode}'),
  );

  /// [amountSat] in [currencyCode], or in the settings currency when none is
  /// given. Without an amount, the price of one bitcoin.
  @useResult
  Future<Result<double, SellFailure>> satsToCurrency({
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
      network: switch (settings.environment) {
        Environment.mainnet => BitcoinNetwork.mainnet,
        Environment.testnet => BitcoinNetwork.testnet,
        Environment.regtest => BitcoinNetwork.regtest,
      },
      currency: currency,
    );
    switch (price) {
      case Ok(:final value):
        return Ok(value.fiatValueOf(amountSat ?? satoshisPerBitcoin));
      // Without a price there is no estimate: a zero rate would need zero
      // sats and pass any balance check.
      case Err(:final failure):
        log.warning('Sell price unavailable: ${failure.runtimeType}');
        return Err(SellQuoteUnavailableFailure(failure.logMessage));
    }
  }

  @useResult
  Future<Result<Order, SellFailure>> order({required String orderId}) async {
    switch (await _account.order(orderId)) {
      case Ok(:final value):
        return Ok(value);
      case Err():
        const diagnostic = 'sell_order_read_failed category=unexpected';
        log.severe(
          message: diagnostic,
          error: Exception(diagnostic),
          trace: StackTrace.current,
        );
        return const Err(SellUnexpectedFailure(diagnostic));
    }
  }
}
