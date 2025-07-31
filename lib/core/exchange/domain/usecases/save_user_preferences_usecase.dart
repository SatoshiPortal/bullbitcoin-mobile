import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SaveUserPreferencesUsecase {
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final SettingsRepository _settingsRepository;

  SaveUserPreferencesUsecase({
    required ExchangeUserRepository mainnetExchangeUserRepository,
    required ExchangeUserRepository testnetExchangeUserRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeUserRepository = mainnetExchangeUserRepository,
       _testnetExchangeUserRepository = testnetExchangeUserRepository,
       _settingsRepository = settingsRepository;

  Future<void> execute({
    String? language,
    String? currency,
    String? dcaEnabled,
    String? autoBuyEnabled,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      final repository =
          isTestnet
              ? _testnetExchangeUserRepository
              : _mainnetExchangeUserRepository;

      await repository.saveUserPreference(
        language: language,
        currency: currency,
        dcaEnabled: dcaEnabled,
        autoBuyEnabled: autoBuyEnabled,
      );
    } catch (e) {
      throw Exception('Failed to save user preferences: $e');
    }
  }
}
