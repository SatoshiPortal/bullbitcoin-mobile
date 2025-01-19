import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyValueStorageDataSourceImpl
    implements KeyValueStorageDataSource<String> {
  final FlutterSecureStorage _storage;

  SecureKeyValueStorageDataSourceImpl(this._storage);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<Map<String, String>> getAll() async {
    return _storage.readAll();
  }

  @override
  Future<String?> getValue(String key) async {
    return _storage.read(key: key);
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
