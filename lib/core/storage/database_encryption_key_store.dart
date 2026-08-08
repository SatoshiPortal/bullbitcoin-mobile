import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

abstract final class DatabaseEncryptionKeyStore {
  static const _key = 'databaseEncryptionKeyV1';

  static Future<String> loadOrCreate({
    required bool hasExistingDatabase,
  }) async {
    final storage = _openStorage();
    final existing = await storage.read(key: _key);
    if (existing != null) {
      _validate(existing);
      return existing;
    }
    ensureKeyCanBeCreated(hasExistingDatabase: hasExistingDatabase);

    final random = Random.secure();
    final generated = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await storage.write(key: _key, value: generated);
    final persisted = await storage.read(key: _key);
    if (persisted == null) {
      throw StateError('Database encryption key was not persisted');
    }
    _validate(persisted);
    return persisted;
  }

  static Future<String?> loadExisting() async {
    final key = await _openStorage().read(key: _key);
    if (key != null) _validate(key);
    return key;
  }

  @visibleForTesting
  static void ensureKeyCanBeCreated({required bool hasExistingDatabase}) {
    if (hasExistingDatabase) {
      throw StateError('Database encryption key is unavailable');
    }
  }

  static FlutterSecureStorage _openStorage() => const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static void _validate(String key) {
    if (base64Url.decode(base64Url.normalize(key)).length != 32) {
      throw StateError('Invalid database encryption key');
    }
  }
}
