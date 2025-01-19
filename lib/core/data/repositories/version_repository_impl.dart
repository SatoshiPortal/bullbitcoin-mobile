import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/domain/repositories/version_repository.dart';

class VersionRepositoryImpl implements VersionRepository {
  final KeyValueStorageDataSource<String> _storage;

  static const _key = 'version';

  VersionRepositoryImpl(this._storage);

  @override
  Future<String?> getVersion() async {
    return await _storage.getValue(_key);
  }

  @override
  Future<void> saveVersion(String version) async {
    await _storage.saveValue(key: _key, value: version);
  }
}
