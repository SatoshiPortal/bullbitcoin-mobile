abstract class HiveEncryptionKeyRepository {
  Future<String?> getEncryptionKey();
  Future<void> saveEncryptionKey(String key);
}
