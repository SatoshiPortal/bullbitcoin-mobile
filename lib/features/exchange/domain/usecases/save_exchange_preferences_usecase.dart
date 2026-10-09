import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:meta/meta.dart';

/// Saves language, currency, notification, DCA and AutoBuy preferences.
///
/// The exchange's `saveUserPreferences` replaces the whole stored set, so
/// every field the caller leaves out is filled from a fresh user summary
/// before the write. A failed summary read aborts the write: pushing a
/// partial or stale set would silently reset the other preferences.
class SaveExchangePreferencesUsecase {
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final SettingsRepository _settingsRepository;

  const SaveExchangePreferencesUsecase({
    required this._mainnetExchangeUserRepository,
    required this._testnetExchangeUserRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute({
    String? language,
    String? currency,
    bool? emailNotificationsEnabled,
    bool? dcaEnabled,
    String? autoBuyEnabled,
  }) async {
    final Environment environment;
    switch (await readExchangeEnvironment(
      _settingsRepository,
      ExchangePreferencesSaveFailure.new,
    )) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        return Err(failure);
    }
    final repo = environment.isTestnet
        ? _testnetExchangeUserRepository
        : _mainnetExchangeUserRepository;

    final UserSummary summary;
    switch (await repo.getUserSummary()) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        return Err(switch (failure) {
          ExchangeUserNotAuthenticatedFailure() =>
            ExchangeNotAuthenticatedFailure(failure.logMessage),
          ExchangeUserNetworkFailure() => ExchangeNetworkFailure(
            failure.logMessage,
          ),
          _ => ExchangePreferencesSaveFailure(failure.logMessage),
        });
    }

    final result = await repo.saveUserPreference(
      language: language ?? summary.language,
      currency: currency ?? summary.currency,
      dcaEnabled: dcaEnabled ?? summary.dca.isActive,
      autoBuyEnabled: autoBuyEnabled ?? summary.autoBuy.isActive.toString(),
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? summary.emailNotificationsEnabled,
    );

    return result.mapErr(
      (failure) => switch (failure) {
        ExchangeUserNetworkFailure() => ExchangeNetworkFailure(
          failure.logMessage,
        ),
        _ => ExchangePreferencesSaveFailure(failure.logMessage),
      },
    );
  }
}
