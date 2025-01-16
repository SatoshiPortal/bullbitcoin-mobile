abstract class KeyValueStorageDataSource {
  Future<void> saveValue({required String key, required String value});
  Future<Map<String, String>> getAll();
  Future<String?> getValue(String key);
  Future<void> deleteValue(String key);
  Future<void> deleteAll();
}
