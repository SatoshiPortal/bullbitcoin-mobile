import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class CheckExchangeApiKeyExistsUsecase {
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;
  final SettingsRepository _settingsRepository;

  CheckExchangeApiKeyExistsUsecase({
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
    required SettingsRepository settingsRepository,
  }) : _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource,
       _settingsRepository = settingsRepository;

  Future<bool> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      final apiKey = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: isTestnet,
      );
      return apiKey != null && apiKey.isActive;
    } catch (e) {
      log.severe('Error in CheckExchangeApiKeyExistsUsecase: $e');
      return false;
    }
  }
}
