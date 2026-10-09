import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Mirrors an app currency change onto the exchange account, when there is
/// one. Skips silently when the user is signed out or the currency is not
/// offered on the exchange — the app-side setting is already saved either way.
class SyncExchangeCurrencyUsecase {
  final SettingsRepository _settingsRepository;
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;

  const SyncExchangeCurrencyUsecase({
    required this._settingsRepository,
    required this._mainnetExchangeUserRepository,
    required this._testnetExchangeUserRepository,
  });

  @useResult
  Future<Result<void, SettingsFailure>> execute(String currencyCode) async {
    final currency = FiatCurrency.tryFromCode(currencyCode);
    if (currency == null) {
      return const Ok(null);
    }

    final Environment environment;
    try {
      environment = (await _settingsRepository.fetch()).environment;
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

    final userRepository = environment.isTestnet
        ? _testnetExchangeUserRepository
        : _mainnetExchangeUserRepository;

    final UserSummary summary;
    switch (await userRepository.getUserSummary()) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        if (failure is ExchangeUserNotAuthenticatedFailure) {
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

    final saved = await userRepository.saveUserPreference(
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
