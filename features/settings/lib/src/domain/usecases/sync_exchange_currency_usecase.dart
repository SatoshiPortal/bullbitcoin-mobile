import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Mirrors an app currency change onto the exchange account, when there is
/// one. Skips when the network has no exchange, the user is signed out or the
/// currency is not offered on the exchange.
class SyncExchangeCurrencyUsecase {
  final Preferences _settingsRepository;
  final Exchange _exchange;

  const SyncExchangeCurrencyUsecase({
    required this._settingsRepository,
    required this._exchange,
  });

  @useResult
  Future<Result<void, SettingsFailure>> execute(String currencyCode) async {
    final currency = FiatCurrency.tryFromCode(currencyCode);
    if (currency == null) {
      return const Ok(null);
    }

    final Environment environment;
    try {
      environment = ((await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      )).environment;
    } on Error {
      rethrow;
    } catch (e, st) {
      log.severe(
        message: 'Failed to read settings before syncing the exchange currency',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(SettingsExchangeSyncFailure('settings fetch failed'));
    }

    if (!NetworkCapabilities.supports(
      BitcoinNetwork.fromName(environment.name),
      NetworkCapability.exchange,
    )) {
      return const Ok(null);
    }
    final exchangeEnvironment = environment.requireHistoricalTestnet()
        ? ExchangeEnvironment.testnet
        : ExchangeEnvironment.mainnet;

    final UserSummary summary;
    switch (await _exchange.getUserSummary(exchangeEnvironment)) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        if (failure is ExchangeNotAuthenticatedFailure) {
          return const Ok(null);
        }
        // Without the summary a preference write would reset the other
        // preferences (the exchange replaces the whole set), so don't write.
        return Err(
          SettingsExchangeSyncFailure(
            failure.logMessage ?? '${failure.runtimeType}',
          ),
        );
    }

    if (summary.currency == currency.code) {
      return const Ok(null);
    }

    final saved = await _exchange.saveUserPreference(
      exchangeEnvironment,
      language: summary.language,
      currency: currency.code,
      dcaEnabled: summary.dca.isActive,
      autoBuyEnabled: summary.autoBuy.isActive.toString(),
      emailNotificationsEnabled: summary.emailNotificationsEnabled,
    );
    if (saved case Err(:final failure)) {
      return Err(SettingsExchangeSyncFailure(failure.logMessage));
    }

    return const Ok(null);
  }
}
