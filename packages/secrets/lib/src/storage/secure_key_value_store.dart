/// The minimal raw secure key/value surface `FssSecretStore` needs. INTERNAL.
///
/// Splitting this out keeps `FssSecretStore`'s logic (key scheme, retry/backoff,
/// locked-keychain handling, base64, legacy-key enumeration) unit-testable with
/// an in-memory fake, while the only thing that touches the platform channel is
/// the thin `FlutterSecureStorageAdapter`.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
  Future<bool> containsKey(String key);
  Future<void> deleteAll();
}
