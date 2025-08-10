import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';

class SecureStorageRepository {
  final KeyValueStorageDatasource<String> _datasource;

  SecureStorageRepository(this._datasource);

  Future<Map<String, String>> getAllKeyValues() async {
    return await _datasource.getAll();
  }
}
