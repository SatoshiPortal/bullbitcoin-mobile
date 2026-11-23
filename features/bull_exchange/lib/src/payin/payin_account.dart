import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

/// Selects the current Exchange account without a throwing app intermediary.
final class PayinAccount {
  final Exchange _exchange;
  final Preferences _preferences;

  const PayinAccount(this._exchange, this._preferences);

  Future<
    Result<
      ({UserSummary userSummary, SettingsEntity settings}),
      ExchangeFailure
    >
  >
  summary() async {
    switch (await _preferences.fetch()) {
      case Ok(value: final settings):
        final environment = _environment(settings.environment);
        if (environment == null) {
          return const Err(ExchangeUnsupportedNetworkFailure());
        }
        return (await _exchange.getUserSummary(environment))
            .map((summary) => (userSummary: summary, settings: settings));
      case Err():
        return const Err(ExchangeAccountUnavailableFailure());
    }
  }

  Future<Result<Order, ExchangeFailure>> order(String orderId) async {
    switch (await _preferences.fetch()) {
      case Ok(value: final settings):
        final environment = _environment(settings.environment);
        if (environment == null) {
          return const Err(ExchangeUnsupportedNetworkFailure());
        }
        final result = await _exchange.orders(environment).getOrder(orderId);
        if (result case Err(:final failure)) {
          log.warning('Exchange order unavailable: ${failure.runtimeType}');
        }
        return result;
      case Err():
        return const Err(ExchangeOrderLoadFailure());
    }
  }

  static ExchangeEnvironment? _environment(Environment environment) =>
      switch (environment) {
        Environment.mainnet => ExchangeEnvironment.mainnet,
        Environment.testnet => ExchangeEnvironment.testnet,
        Environment.regtest => null,
      };
}
