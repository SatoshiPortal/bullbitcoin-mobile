import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:flutter/foundation.dart';

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

      debugPrint('API key saved successfully');
    } catch (e) {
      debugPrint('Error in SaveApiKeyUsecase: $e');
      throw SaveExchangeApiKeyException('$e');
    }
  }
}

class SaveExchangeApiKeyException implements Exception {
  final String message;

  SaveExchangeApiKeyException(this.message);

  @override
  String toString() => '[SaveExchangeApiKeyUsecase]: $message';
}
