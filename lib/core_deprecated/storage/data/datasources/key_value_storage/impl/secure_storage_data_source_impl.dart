import 'package:bb_mobile/core_deprecated/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageDatasourceImpl implements KeyValueStorageDatasource<String> {
  final FlutterSecureStorage _storage;

  SecureStorageDatasourceImpl(this._storage);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<Map<String, String>> getAll() {
    return _storage.readAll();
  }

  @override
  Future<String?> getValue(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<bool> hasValue(String key) {
    return _storage.containsKey(key: key);
  }

  @override
  Future<void> deleteValue(String key) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
