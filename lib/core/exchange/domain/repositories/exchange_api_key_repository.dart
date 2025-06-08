abstract class ExchangeApiKeyRepository {
  Future<void> saveApiKey(
    Map<String, dynamic> apiKeyResponseData, {
    required bool isTestnet,
  });
  Future<void> deleteApiKey({required bool isTestnet});
}
