import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SaveExchangeApiKeyUsecase {
  final ExchangeApiKeyRepository _exchangeApiKeyRepository;

  SaveExchangeApiKeyUsecase({required this._exchangeApiKeyRepository});

  Future<void> execute({
    required Map<String, dynamic> apiKeyResponseData,
    required bool isTestnet,
  }) async {
    try {
      await _exchangeApiKeyRepository.saveApiKey(
        apiKeyResponseData,
        isTestnet: isTestnet,
      );

      log.fine('API key saved successfully');
    } catch (_) {
      log.warning('Unable to import Bull Bitcoin credentials');
      throw SaveExchangeApiKeyException(
        'Unable to import Bull Bitcoin credentials',
      );
    }
  }
}

class SaveExchangeApiKeyException extends BullException {
  SaveExchangeApiKeyException(super.message);
}
