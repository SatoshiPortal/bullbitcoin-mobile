import 'package:bb_mobile/core/data/datasources/impl/secure_storage_data_source.dart';
import 'package:bb_mobile/core/domain/repositories/hive_encryption_key_repository.dart';

class HiveEncryptionKeyRepositoryImpl implements HiveEncryptionKeyRepository {
  final SecureStorageDataSource _secureStorage;

  static const _key = 'hiveEncryptionKey';

  HiveEncryptionKeyRepositoryImpl(this._secureStorage);

  @override
  Future<String?> getEncryptionKey() async {
    return await _secureStorage.getValue(_key);
  }

  @override
  Future<void> saveEncryptionKey(String key) async {
    await _secureStorage.saveValue(key: _key, value: key);
  }
}
