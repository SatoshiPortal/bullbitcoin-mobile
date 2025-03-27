abstract class KeyValueStorageDatasource<T> {
  Future<void> saveValue({required String key, required T value});
  Future<Map<String, T>> getAll();
  Future<T?> getValue(String key);
  Future<bool> hasValue(String key);
  Future<void> deleteValue(String key);
  Future<void> deleteAll();
}
