import 'package:bb_mobile/core/datasources/key_value_storage_data_source.dart';
import 'package:hive/hive.dart';

class HiveStorageDataSource implements KeyValueStorageDataSource {
  final Box<String> _box;

  HiveStorageDataSource(this._box);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    await _box.put(key, value);
  }

  @override
  Future<Map<String, String>> getAll() async {
    return _box.toMap().cast<String, String>();
  }

  @override
  Future<String?> getValue(String key) async {
    return _box.get(key);
  }

  @override
  Future<void> deleteValue(String key) async {
    await _box.delete(key);
  }

  @override
  Future<void> deleteAll() async {
    await _box.clear();
  }
}
