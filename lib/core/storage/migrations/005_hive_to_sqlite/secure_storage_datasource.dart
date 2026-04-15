import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';

class MigrationSecureStorageDatasource {
  final KeyValueStorageDatasource<String> _storage;

  MigrationSecureStorageDatasource(this._storage);

  Future<void> store({required String key, required String value}) async {
    await _storage.saveValue(key: key, value: value);
  }

  Future<String?> fetch({required String key}) async {
    return await _storage.getValue(key);
  }

  Future<OldSeed> oldSeedFetch(String fingerprint) async {
    final jsn = await _storage.getValue(fingerprint);
    if (jsn == null) throw Exception('No seed found');
    final obj = json.decode(jsn) as Map<String, dynamic>;
    final seed = OldSeed.fromJson(obj);
    seed.mnemonicFingerprint;
    return seed;
  }
}
