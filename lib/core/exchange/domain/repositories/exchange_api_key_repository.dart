abstract class ExchangeApiKeyRepository {
  Future<void> saveApiKey(Map<String, dynamic> apiKeyResponseData);
  Future<void> deleteApiKey();
}
