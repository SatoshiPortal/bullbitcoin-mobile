import 'package:bb_mobile/core_deprecated/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core_deprecated/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/exchange_api_key_repository.dart';

class ExchangeApiKeyRepositoryImpl implements ExchangeApiKeyRepository {
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;

  ExchangeApiKeyRepositoryImpl({
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
  }) : _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource;

  @override
  Future<void> saveApiKey(
    Map<String, dynamic> apiKeyResponseData, {
    required bool isTestnet,
  }) async {
    Map<String, dynamic> apiKeyData;

    // Check various formats the API might return
    if (apiKeyResponseData.containsKey('apiKey')) {
      // Format: { "apiKey": { ... } }
      apiKeyData = apiKeyResponseData['apiKey'] as Map<String, dynamic>;
    } else if (apiKeyResponseData.containsKey('result') &&
        apiKeyResponseData['result'] is Map &&
        (apiKeyResponseData['result'] as Map).containsKey('apiKey')) {
      // Format: { "result": { "apiKey": { ... } } }
      apiKeyData =
          apiKeyResponseData['result']['apiKey'] as Map<String, dynamic>;
    } else if (apiKeyResponseData.containsKey('data') &&
        apiKeyResponseData['data'] is Map &&
        (apiKeyResponseData['data'] as Map).containsKey('apiKey')) {
      // Format: { "data": { "apiKey": { ... } } }
      apiKeyData = apiKeyResponseData['data']['apiKey'] as Map<String, dynamic>;
    } else {
      apiKeyData = apiKeyResponseData;
    }

    final apiKeyModel = ExchangeApiKeyModel.fromJson(apiKeyData);

    try {
      await _bullbitcoinApiKeyDatasource.store(
        apiKeyModel,
        isTestnet: isTestnet,
      );
    } catch (e) {
      throw Exception('Failed to save API key: $e');
    }
  }

  @override
  Future<void> deleteApiKey({required bool isTestnet}) async {
    await _bullbitcoinApiKeyDatasource.delete(isTestnet: isTestnet);
  }
}
