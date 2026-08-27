import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class DeleteExchangeApiKeyUsecase {
  final ExchangeApiKeyRepository _exchangeApiKeyRepository;
  final SettingsRepository _settingsRepository;

  DeleteExchangeApiKeyUsecase({
    required this._exchangeApiKeyRepository,
    required this._settingsRepository,
  });

  Future<void> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      await _exchangeApiKeyRepository.deleteApiKey(isTestnet: isTestnet);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      throw DeleteExchangeApiKeyException('$e');
    }
  }
}

class DeleteExchangeApiKeyException extends BullException {
  DeleteExchangeApiKeyException(super.message);
}
