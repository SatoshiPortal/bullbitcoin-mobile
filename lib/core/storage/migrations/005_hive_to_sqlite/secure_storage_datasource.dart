import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_v9/flutter_secure_storage_v9.dart'
    as fss_v9;

class MigrationSecureStorageDatasource {
  final FlutterSecureStorage _storage;
  final fss_v9.FlutterSecureStorageV9 _storageV9;

  MigrationSecureStorageDatasource(
    this._storage, {
    required fss_v9.FlutterSecureStorageV9 storageV9,
  }) : _storageV9 = storageV9;

  Future<void> store({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      await _migrateFromV9Storage();
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> fetch({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      await _migrateFromV9Storage();
      return await _storage.read(key: key);
    }
  }

  Future<OldSeed> oldSeedFetch(String fingerprint) async {
    try {
      return await _oldSeedFetch(fingerprint);
    } catch (e) {
      await _migrateFromV9Storage();
      return await _oldSeedFetch(fingerprint);
    }
  }

  Future<void> _migrateFromV9Storage() async {
    // Fallback to v9 storage if v10 fails
    final values = await _storageV9.readAll();
    if (values.isNotEmpty) {
      // Migrate values back to v10 storage
      for (final entry in values.entries) {
        await _storage.write(
          key: entry.key,
          value: entry.value,
          aOptions: AndroidOptions(resetOnError: true),
        );
      }
    }
  }

  Future<OldSeed> _oldSeedFetch(String fingerprint) async {
    final jsn = await _storage.read(key: fingerprint);
    if (jsn == null) throw Exception('No seed found');
    final obj = json.decode(jsn) as Map<String, dynamic>;
    final seed = OldSeed.fromJson(obj);
    seed.mnemonicFingerprint;
    return seed;
  }
}
