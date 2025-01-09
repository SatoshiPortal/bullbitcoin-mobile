import 'package:bb_mobile/core/datasources/impl/secure_storage_data_source.dart';

abstract class VersionRepository {
  Future<String?> getVersion();
  Future<void> saveVersion(String version);
}

class VersionRepositoryImpl implements VersionRepository {
  final SecureStorageDataSource _secureStorage;

  static const _key = 'version';

  VersionRepositoryImpl(this._secureStorage);

  @override
  Future<String?> getVersion() async {
    return await _secureStorage.getValue(_key);
  }

  @override
  Future<void> saveVersion(String version) async {
    await _secureStorage.saveValue(key: _key, value: version);
  }
}
