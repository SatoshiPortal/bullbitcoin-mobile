import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesDatasourceImpl
    implements KeyValueStorageDatasource<String> {
  final SharedPreferencesAsync _storage;

  SharedPreferencesDatasourceImpl(this._storage);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    await _storage.setString(key, value);
  }

  @override
  Future<Map<String, String>> getAll() async => await getAll();

  @override
  Future<String?> getValue(String key) async => await _storage.getString(key);

  @override
  Future<bool> hasValue(String key) async => await _storage.containsKey(key);

  @override
  Future<void> deleteValue(String key) async => await _storage.remove(key);

  @override
  Future<void> deleteAll() async => await _storage.clear();

  Future<List<String>?> getValues(String key) async {
    return await _storage.getStringList(key);
  }

  Future<void> saveValues(String key, List<String> values) async {
    await _storage.setStringList(key, values);
  }
}
