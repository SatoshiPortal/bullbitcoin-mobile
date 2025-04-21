import 'package:bb_mobile/core/exchange/data/datasources/api_key_storage_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';

class GetApiKeyUsecase {
  final ApiKeyStorageDatasource _apiKeyStorage;

  GetApiKeyUsecase({
    required ApiKeyStorageDatasource apiKeyStorage,
  }) : _apiKeyStorage = apiKeyStorage;

  Future<ExchangeApiKeyModel?> call() async {
    return await _apiKeyStorage.get();
  }
}
