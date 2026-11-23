import '../setup/exchange_access_lifecycle.dart';

import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import 'read_exchange_environment.dart';

import 'package:meta/meta.dart';

/// Saves language, currency, notification, DCA and AutoBuy preferences.
///
/// The exchange's `saveUserPreferences` replaces the whole stored set, so
/// every field the caller leaves out is filled from a fresh user summary
/// before the write. A failed summary read aborts the write: pushing a
/// partial or stale set would silently reset the other preferences.
class SaveExchangePreferencesUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;
  final ExchangeAccessLifecycle _access;

  const SaveExchangePreferencesUsecase({
    required this._exchange,
    required this._settingsRepository,
    required this._access,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute({
    String? language,
    String? currency,
    bool? emailNotificationsEnabled,
    bool? dcaEnabled,
    String? autoBuyEnabled,
  }) async {
    if (_access.current is! ExchangeAccessEnabled ||
        (_access.current as ExchangeAccessEnabled).session !=
            ExchangeAccessSession.signedIn) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    final epoch = _access.epoch;
    final Environment environment;
    final readEnvironment = await readExchangeEnvironment(
      _settingsRepository,
      ExchangePreferencesSaveFailure.new,
    );
    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    switch (readEnvironment) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    final exchangeEnvironment = environment == Environment.testnet
        ? ExchangeEnvironment.testnet
        : ExchangeEnvironment.mainnet;

    final UserSummary summary;
    final readSummary = await _exchange.getUserSummary(exchangeEnvironment);
    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    switch (readSummary) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        return Err(switch (failure) {
          ExchangeNotAuthenticatedFailure() ||
          ExchangeNetworkFailure() => failure,
          _ => ExchangePreferencesSaveFailure(failure.logMessage),
        });
    }

    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    final result = await _exchange.saveUserPreference(
      exchangeEnvironment,
      language: language ?? summary.language,
      currency: currency ?? summary.currency,
      dcaEnabled: dcaEnabled ?? summary.dca.isActive,
      autoBuyEnabled: autoBuyEnabled ?? summary.autoBuy.isActive.toString(),
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? summary.emailNotificationsEnabled,
    );

    if (_access.epoch != epoch) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return result.mapErr(
      (failure) => switch (failure) {
        ExchangeNetworkFailure() => failure,
        _ => ExchangePreferencesSaveFailure(failure.logMessage),
      },
    );
  }
}
