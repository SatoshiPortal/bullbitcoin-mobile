import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

/// Saves language, currency, notification and DCA preferences. The repository
/// sanitizes; this only lifts the core failure into the feature's family.
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
    final settings = await _settingsRepository.fetch();
    final repo = settings.environment.isTestnet
        ? _testnetExchangeUserRepository
        : _mainnetExchangeUserRepository;

    final result = await repo.saveUserPreference(
      language: language,
      currency: currency,
      dcaEnabled: dcaEnabled,
      autoBuyEnabled: autoBuyEnabled,
      emailNotificationsEnabled: emailNotificationsEnabled,
    );

    return result.mapErr(
      (failure) => ExchangePreferencesSaveFailure(failure.logMessage),
    );
  }
}
