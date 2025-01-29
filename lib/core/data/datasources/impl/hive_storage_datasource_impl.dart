import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:hive/hive.dart';

class HiveStorageDataSourceImpl<T> implements KeyValueStorageDataSource<T> {
  final Box<T> _box;

  HiveStorageDataSourceImpl(this._box);

  @override
  Future<void> saveValue({required String key, required T value}) async {
    await _box.put(key, value);
  }

  @override
  Future<Map<String, T>> getAll() async {
    return _box.toMap().cast<String, T>();
  }

  @override
  Future<T?> getValue(String key) async {
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
