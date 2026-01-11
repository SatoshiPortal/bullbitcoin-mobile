import 'dart:convert';

import 'package:bb_mobile/features/seeds/interface_adapters/seed_secrets/seed_secret_datasource.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/seed_secrets/seed_secret_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FssSeedSecretDatasource implements SeedSecretDatasource {
  final FlutterSecureStorage _flutterSecureStorage;
  static const String _prefix = 'seed_';

  const FssSeedSecretDatasource({
    required FlutterSecureStorage flutterSecureStorage,
  }) : _flutterSecureStorage = flutterSecureStorage;

  Future<void> store({
    required String fingerprint,
    required SeedSecretModel seed,
  }) {
    final key = composeSeedStorageKey(fingerprint);
    final value = jsonEncode(seed.toJson());
    return _flutterSecureStorage.write(key: key, value: value);
  }

  Future<SeedSecretModel?> get(String fingerprint) async {
    final key = composeSeedStorageKey(fingerprint);
    final value = await _flutterSecureStorage.read(key: key);
    if (value == null) {
      return null;
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final seed = SeedSecretModel.fromJson(json);

    return seed;
  }

  Future<bool> exists(String fingerprint) {
    final key = composeSeedStorageKey(fingerprint);
    return _flutterSecureStorage.containsKey(key: key);
  }

  Future<List<SeedSecretModel>> getAll() async {
    final allEntries = await _flutterSecureStorage.readAll();
    // Top-level function for isolate processing
    @pragma('vm:entry-point')
    List<SeedSecretModel> parseSeedsInIsolate(Map<String, String> allEntries) {
      final seeds = <SeedSecretModel>[];

      for (final entry in allEntries.entries) {
        try {
          final key = entry.key;
          final value = entry.value;
          if (value.isEmpty) continue;

          // Only process keys that start with the seed prefix
          if (!key.startsWith(_prefix)) {
            continue;
          }

          // Try to parse as SeedSecretModel JSON
          final json = jsonDecode(value) as Map<String, dynamic>;
          final seedModel = SeedSecretModel.fromJson(json);
          seeds.add(seedModel);
        } catch (e) {
          // Skip keys that are not seed objects
          continue;
        }
      }

      return seeds;
    }

    // Parse entries in isolate to avoid blocking UI
    return await compute(parseSeedsInIsolate, allEntries);
  }

  Future<void> delete(String fingerprint) {
    final key = composeSeedStorageKey(fingerprint);
    return _flutterSecureStorage.delete(key: key);
  }

  static String composeSeedStorageKey(String fingerprint) =>
      '$_prefix$fingerprint';
}
