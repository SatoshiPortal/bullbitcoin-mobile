import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

/// Persists the API key the auth webview produced. The repository sanitizes;
/// this only lifts the core failure into the feature's family.
class StoreExchangeApiKeyUsecase {
  final ExchangeApiKeyRepository _exchangeApiKeyRepository;
  final SettingsRepository _settingsRepository;

  const StoreExchangeApiKeyUsecase({
    required this._exchangeApiKeyRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute(
    Map<String, dynamic> apiKeyResponseData,
  ) async {
    final settings = await _settingsRepository.fetch();

    final result = await _exchangeApiKeyRepository.saveApiKey(
      apiKeyResponseData,
      isTestnet: settings.environment.isTestnet,
    );

    return result.mapErr(
      (failure) => ExchangeApiKeyStorageFailure(failure.logMessage),
    );
  }
}
