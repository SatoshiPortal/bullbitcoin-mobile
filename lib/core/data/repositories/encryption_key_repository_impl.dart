import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/domain/repositories/hive_encryption_key_repository.dart';

class EncryptionKeyRepositoryImpl implements HiveEncryptionKeyRepository {
  final KeyValueStorageDataSource<String> _storage;

  static const _key = 'hiveEncryptionKey';

  EncryptionKeyRepositoryImpl(this._storage);

  @override
  Future<String?> getEncryptionKey() async {
    return await _storage.getValue(_key);
  }

  @override
  Future<void> saveEncryptionKey(String key) async {
    await _storage.saveValue(key: _key, value: key);
  }
}
