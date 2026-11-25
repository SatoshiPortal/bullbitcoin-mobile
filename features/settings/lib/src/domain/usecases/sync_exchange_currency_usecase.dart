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
    final FiatCurrency currency;
    switch (ExchangeCatalog.parse(currencyCode)) {
      case KnownCurrency(currency: final known):
        currency = known;
      case UnknownCurrency():
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
    // The writer re-reads the account, so a currency it already has sends
    // nothing and the other preferences are kept.
    switch (await _exchange.updateCurrentPreferences(
      ExchangePreferencesPatch(currency: currency.code),
    )) {
      case Ok() || Err(failure: ExchangeNotAuthenticatedFailure()):
        break;
      case Err(:final failure):
        return Err(
          SettingsExchangeSyncFailure(
            failure.logMessage ?? '${failure.runtimeType}',
          ),
        );
    }

    return const Ok(null);
  }
}
