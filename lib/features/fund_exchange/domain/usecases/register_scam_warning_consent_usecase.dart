import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class RegisterScamWarningConsentUsecase {
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final SettingsRepository _settingsRepository;

  RegisterScamWarningConsentUsecase({
    required ExchangeUserRepository mainnetExchangeUserRepository,
    required ExchangeUserRepository testnetExchangeUserRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeUserRepository = mainnetExchangeUserRepository,
       _testnetExchangeUserRepository = testnetExchangeUserRepository,
       _settingsRepository = settingsRepository;

  Future<void> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeUserRepository
              : _mainnetExchangeUserRepository;
      await repo.registerScamWarningConsent();
    } catch (e) {
      if (e is ApiKeyException) {
        rethrow;
      }
      throw RegisterScamWarningConsentException('$e');
    }
  }
}

class RegisterScamWarningConsentException extends BullException {
  RegisterScamWarningConsentException(super.message);
}
