import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class ToggleEmailNotificationsUsecase {
  final ExchangeUserRepository _mainnetRepository;
  final ExchangeUserRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  ToggleEmailNotificationsUsecase({
    required ExchangeUserRepository mainnetExchangeUserRepository,
    required ExchangeUserRepository testnetExchangeUserRepository,
    required SettingsRepository settingsRepository,
  })  : _mainnetRepository = mainnetExchangeUserRepository,
        _testnetRepository = testnetExchangeUserRepository,
        _settingsRepository = settingsRepository;

  Future<void> execute({required bool enabled}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet ? _testnetRepository : _mainnetRepository;

      await repo.saveUserPreferences(emailNotificationsEnabled: enabled);
    } catch (e) {
      throw ToggleEmailNotificationsException('$e');
    }
  }
}

class ToggleEmailNotificationsException extends BullException {
  ToggleEmailNotificationsException(super.message);
}






