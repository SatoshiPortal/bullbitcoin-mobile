import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/storage/secure_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MigrationSecureStorageDatasource {
  final FlutterSecureStorage _storage;

  MigrationSecureStorageDatasource() : _storage = SecureStorage.init();

  Future<void> store({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> fetch({required String key}) async {
    return await _storage.read(key: key);
  }

  Future<OldSeed> oldSeedFetch(String fingerprint) async {
    final jsn = await _storage.read(key: fingerprint);
    if (jsn == null) throw Exception('No seed found');
    final obj = json.decode(jsn) as Map<String, dynamic>;
    final seed = OldSeed.fromJson(obj);
    seed.mnemonicFingerprint;
    return seed;
  }
}
