import 'dart:convert';

import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core_deprecated/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:flutter/foundation.dart';

class SeedDatasource {
  final KeyValueStorageDatasource<String> _secureStorage;

  const SeedDatasource({
    required KeyValueStorageDatasource<String> secureStorage,
  }) : _secureStorage = secureStorage;

  Future<void> store({required String fingerprint, required SeedModel seed}) {
    final key = composeSeedStorageKey(fingerprint);
    final value = jsonEncode(seed.toJson());
    return _secureStorage.saveValue(key: key, value: value);
  }

  Future<SeedModel> get(String fingerprint) async {
    final key = composeSeedStorageKey(fingerprint);
    final value = await _secureStorage.getValue(key);
    if (value == null) {
      throw SeedNotFoundException(
        'Seed not found for fingerprint: $fingerprint',
      );
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final seed = SeedModel.fromJson(json);

    return seed;
  }

  Future<bool> exists(String fingerprint) {
    final key = composeSeedStorageKey(fingerprint);
    return _secureStorage.hasValue(key);
  }

  Future<void> delete(String fingerprint) {
    final key = composeSeedStorageKey(fingerprint);
    return _secureStorage.deleteValue(key);
  }

  Future<List<SeedModel>> getAll() async {
    final allEntries = await _secureStorage.getAll();
    // Top-level function for isolate processing
    @pragma('vm:entry-point')
    List<SeedModel> parseSeedsInIsolate(Map<String, String> allEntries) {
      final seeds = <SeedModel>[];

      for (final entry in allEntries.entries) {
        try {
          final key = entry.key;
          final value = entry.value;
          if (value.isEmpty) continue;

          // Only process keys that start with the seed prefix
          if (!key.startsWith(SecureStorageKeyPrefixConstants.seed)) {
            continue;
          }

          // Try to parse as SeedModel JSON
          final json = jsonDecode(value) as Map<String, dynamic>;
          final seedModel = SeedModel.fromJson(json);
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

  static String composeSeedStorageKey(String fingerprint) =>
      '${SecureStorageKeyPrefixConstants.seed}$fingerprint';
}

class SeedNotFoundException extends BullException {
  SeedNotFoundException(super.message);
}
