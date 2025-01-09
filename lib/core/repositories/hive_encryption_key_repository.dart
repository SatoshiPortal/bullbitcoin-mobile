import 'package:bb_mobile/core/datasources/impl/secure_storage_data_source.dart';

abstract class HiveEncryptionKeyRepository {
  Future<String?> getEncryptionKey();
  Future<void> saveEncryptionKey(String key);
}

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
