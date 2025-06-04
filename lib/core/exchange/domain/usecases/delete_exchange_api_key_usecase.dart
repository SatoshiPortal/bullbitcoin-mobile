import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:flutter/foundation.dart';

class DeleteExchangeApiKeyUsecase {
  final ExchangeApiKeyRepository _exchangeApiKeyRepository;

  DeleteExchangeApiKeyUsecase({
    required ExchangeApiKeyRepository exchangeApiKeyRepository,
  }) : _exchangeApiKeyRepository = exchangeApiKeyRepository;

  Future<void> execute() async {
    try {
      await _exchangeApiKeyRepository.deleteApiKey();
    } catch (e) {
      debugPrint('Error in DeleteExchangeApiKeyUsecase: $e');
      throw DeleteExchangeApiKeyException('$e');
    }
  }
}

class DeleteExchangeApiKeyException implements Exception {
  final String message;

  DeleteExchangeApiKeyException(this.message);

  @override
  String toString() => '[SaveExchangeApiKeyUsecase]: $message';
}
