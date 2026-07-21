abstract class ExchangeApiKeyRepository {
  Future<void> saveApiKey(
    Map<String, dynamic> apiKeyResponseData, {
    required bool isTestnet,
  });
  Future<void> deleteApiKey({required bool isTestnet});

  /// Whether an ordinary Bull Bitcoin account key is stored for [isTestnet] on
  /// this device. A local-only presence check (no network I/O); a read error is
  /// reported as absent rather than thrown.
  Future<bool> hasApiKey({required bool isTestnet});
}
