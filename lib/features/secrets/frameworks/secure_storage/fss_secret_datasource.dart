import 'dart:convert';

import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_datasource.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FssSecretDatasource implements SecretDatasource {
  final FlutterSecureStorage _flutterSecureStorage;
  // Keep it named seed to be compatible with existing stored keys with this prefix
  static const String _prefix = 'seed_';

  const FssSecretDatasource({
    required FlutterSecureStorage flutterSecureStorage,
  }) : _flutterSecureStorage = flutterSecureStorage;

  @override
  Future<void> store({
    required String fingerprint,
    required SecretModel secret,
  }) {
    final key = composeSeedStorageKey(fingerprint);
    final value = jsonEncode(secret.toJson());
    return _flutterSecureStorage.write(key: key, value: value);
  }

  @override
  Future<SecretModel?> get(String fingerprint) async {
    final key = composeSeedStorageKey(fingerprint);
    final value = await _flutterSecureStorage.read(key: key);
    if (value == null) {
      return null;
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final secret = SecretModel.fromJson(json);

    return secret;
  }

  @override
  Future<bool> exists(String fingerprint) {
    final key = composeSeedStorageKey(fingerprint);
    return _flutterSecureStorage.containsKey(key: key);
  }

  @override
  Future<Map<String, SecretModel>> getAll() async {
    final allEntries = await _flutterSecureStorage.readAll();
    // Top-level function for isolate processing
    @pragma('vm:entry-point')
    Map<String, SecretModel> parseSeedsInIsolate(
      Map<String, String> allEntries,
    ) {
      final secretsByFingerprint = <String, SecretModel>{};

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
          final secretModel = SecretModel.fromJson(json);
          final fingerprint = extractFingerprintFromStorageKey(key);
          secretsByFingerprint[fingerprint] = secretModel;
        } catch (e) {
          // Skip keys that are not seed objects
          continue;
        }
      }

      return secretsByFingerprint;
    }

    // Parse entries in isolate to avoid blocking UI
    return await compute(parseSeedsInIsolate, allEntries);
  }

  @override
  Future<void> delete(String fingerprint) {
    final key = composeSeedStorageKey(fingerprint);
    return _flutterSecureStorage.delete(key: key);
  }

  static String composeSeedStorageKey(String fingerprint) =>
      '$_prefix$fingerprint';

  static String extractFingerprintFromStorageKey(String storageKey) {
    return storageKey.replaceFirst(_prefix, '');
  }
}
