import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class CheckSinpeUsecase {
  final ExchangeRecipientRepository _mainnetExchangeRecipientRepository;
  final ExchangeRecipientRepository _testnetExchangeRecipientRepository;
  final SettingsRepository _settingsRepository;

  CheckSinpeUsecase({
    required ExchangeRecipientRepository mainnetExchangeRecipientRepository,
    required ExchangeRecipientRepository testnetExchangeRecipientRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRecipientRepository = mainnetExchangeRecipientRepository,
       _testnetExchangeRecipientRepository = testnetExchangeRecipientRepository,
       _settingsRepository = settingsRepository;

  Future<String> execute({required String phoneNumber}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeRecipientRepository
              : _mainnetExchangeRecipientRepository;
      final ownerName = await repo.checkSinpe(phoneNumber: phoneNumber);
      return ownerName;
    } catch (e) {
      log.severe('Error in CheckSinpeUsecase: $e');
      throw CheckSinpeException('$e');
    }
  }
}

class CheckSinpeException extends BullException {
  CheckSinpeException(super.message);
}
