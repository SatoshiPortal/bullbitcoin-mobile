import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';

class SaveExchangeApiKeyUsecase {
  final ExchangeApiKeyRepository _exchangeApiKeyRepository;
  final SettingsRepository _settingsRepository;

  SaveExchangeApiKeyUsecase({
    required ExchangeApiKeyRepository exchangeApiKeyRepository,
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository,
       _exchangeApiKeyRepository = exchangeApiKeyRepository;

  Future<void> execute({
    required Map<String, dynamic> apiKeyResponseData,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      await _exchangeApiKeyRepository.saveApiKey(
        apiKeyResponseData,
        isTestnet: isTestnet,
      );

      log.fine('API key saved successfully');
    } catch (e) {
      log.severe('Error in SaveApiKeyUsecase: $e');
      throw SaveExchangeApiKeyException('$e');
    }
  }
}

class SaveExchangeApiKeyException extends BullException {
  SaveExchangeApiKeyException(super.message);
}
