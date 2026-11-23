import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../../exchange_payout_wallets.dart';
import 'map_buy_order_failure.dart';

class LoadBuyContextUsecase {
  final Exchange _exchange;
  final Preferences _getSettingsUsecase;
  final ExchangePayoutWallets _payouts;
  final Fees _fees;
  final IndexPriceReader _getIndexPrice;

  const LoadBuyContextUsecase({
    required this._exchange,
    required this._getSettingsUsecase,
    required this._payouts,
    required this._fees,
    required this._getIndexPrice,
  });

  BuyFailure _mapAccountFailure(ExchangeFailure failure) => switch (failure) {
    ExchangeCredentialReadFailure() => const BuyUnauthenticatedFailure(),
    _ => mapBuyOrderFailure(failure),
  };

  /// The exchange account summary and the app settings, which the buy screen
  /// needs together before it can show anything.
  @useResult
  Future<
    Result<({UserSummary userSummary, SettingsEntity settings}), BuyFailure>
  >
  userSummaryAndSettings() async {
    try {
      final settings = (await _getSettingsUsecase.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (settings.environment == Environment.regtest) {
        return const Err(BuyUnsupportedNetworkFailure());
      }
      final environment = settings.environment == Environment.testnet
          ? ExchangeEnvironment.testnet
          : ExchangeEnvironment.mainnet;
      return (await _exchange.getUserSummary(environment))
          .map((summary) => (userSummary: summary, settings: settings))
          .mapErr(_mapAccountFailure);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to load the exchange user summary or settings',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
    }
  }

  @useResult
  Future<Result<List<WalletRegistration>, BuyFailure>> wallets(
    Environment environment,
  ) async {
    if (environment == Environment.regtest) {
      return const Err(BuyUnsupportedNetworkFailure());
    }
    final bitcoin = BitcoinNetwork.fromName(environment.name);
    final liquid = LiquidNetwork.fromName(environment.name);
    final wallets = <WalletRegistration>[];
    for (final network in <Network>[bitcoin, liquid]) {
      switch (await _payouts.walletsForNetwork(network)) {
        case Ok(:final value):
          wallets.addAll(
            value.wallets.where((wallet) => wallet.network == network),
          );
        case Err(:final failure):
          return Err(BuyUnexpectedFailure('wallets: ${failure.runtimeType}'));
      }
    }
    return Ok(wallets);
  }

  /// Preserve the preferred Liquid default without choosing between conflicts.
  static WalletRegistration? initialWallet(List<WalletRegistration> wallets) {
    final liquidDefaults = wallets
        .where((wallet) => wallet.isDefault && wallet.network is LiquidNetwork)
        .toList();
    return switch (liquidDefaults) {
      [final wallet] => wallet,
      [] => wallets.firstOrNull,
      _ => null,
    };
  }

  /// The address the exchange will pay out to.
  @useResult
  Future<Result<String, BuyFailure>> receiveAddress({
    required WalletRegistration wallet,
  }) async {
    final address = await _payouts.receive(wallet, advance: false);
    return address == null
        ? const Err(BuyUnexpectedFailure('Buy receive address unavailable'))
        : Ok(address);
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
          return Err(BuyUnexpectedFailure(reason));
      }
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to load the network fees',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
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
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the buy price',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
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
            amountSat ?? BigInt.from(ConvertAmount.btcToSats(1)),
          ),
        );
      case Err(:final failure):
        log.warning('Buy price unavailable: ${failure.runtimeType}');
        return Err(BuyQuoteUnavailableFailure(failure.logMessage));
    }
  }
}
