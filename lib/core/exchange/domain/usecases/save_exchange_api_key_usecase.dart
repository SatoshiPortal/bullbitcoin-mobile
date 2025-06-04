import 'dart:convert';

import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:flutter/foundation.dart';

class SaveExchangeApiKeyUsecase {
  final ExchangeApiKeyRepository _exchangeApiKeyRepository;

  SaveExchangeApiKeyUsecase({
    required ExchangeApiKeyRepository exchangeApiKeyRepository,
  }) : _exchangeApiKeyRepository = exchangeApiKeyRepository;

  Future<void> execute(String apiKeyResponseJson) async {
    try {
      final Map<String, dynamic> responseData =
          json.decode(apiKeyResponseJson) as Map<String, dynamic>;

      await _exchangeApiKeyRepository.saveApiKey(responseData);

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
