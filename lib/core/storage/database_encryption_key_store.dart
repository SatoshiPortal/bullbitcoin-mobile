import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/storage/database_key_unavailable_exception.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

abstract final class DatabaseEncryptionKeyStore {
  static const _key = 'databaseEncryptionKeyV1';

  /// Reads the per-installation database key, creating one only when it
  /// is safe to do so.
  ///
  /// Three outcomes, and keeping them apart is the whole point of this
  /// method:
  ///
  /// - key present → return it;
  /// - keychain temporarily locked → throw [KeychainLockedException]
  ///   **before** the creation path is reachable, so a boot that
  ///   happens before first unlock can never mint a replacement key
  ///   over an existing encrypted database;
  /// - key genuinely absent while a database exists → throw
  ///   [DatabaseKeyUnavailableException] (fail closed).
  ///
  /// Only the third case is a permanent condition, and even then this
  /// method never deletes anything — the user is asked first.
  static Future<String> loadOrCreate({
    required bool hasDatabaseRequiringExistingKey,
  }) async {
    final storage = _openStorage();
    final existing = await _read(storage);
    if (existing != null) {
      _validate(existing);
      return existing;
    }
    // Reached only when the keychain answered "no such item" — a locked
    // keychain has already thrown above.
    ensureKeyCanBeCreated(
      hasDatabaseRequiringExistingKey: hasDatabaseRequiringExistingKey,
    );

    final random = Random.secure();
    final generated = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _guardKeychain(() => storage.write(key: _key, value: generated));
    final persisted = await _read(storage);
    if (persisted == null) {
      throw const DatabaseKeyUnavailableException(
        'database encryption key was not persisted',
      );
    }
    _validate(persisted);
    return persisted;
  }

  /// Read-only variant for callers that must never create a key — the
  /// workmanager background isolate above all, which can run before the
  /// user has ever unlocked the device.
  ///
  /// Returns null only for a genuinely absent key. A locked keychain
  /// throws [KeychainLockedException] so the caller can retry later
  /// instead of reading the absence as "no database yet".
  static Future<String?> loadExisting() async {
    final key = await _read(_openStorage());
    if (key != null) _validate(key);
    return key;
  }

  /// Drops the stored key so the next [loadOrCreate] mints a fresh one.
  ///
  /// Only ever called as part of an explicit, user-confirmed local-data
  /// reset, and only *after* the encrypted databases it opens have been
  /// deleted — dropping the key while the databases are still on disk
  /// is exactly the unreadable-database state this whole area exists to
  /// avoid. See `LocalDatabaseReset`.
  static Future<void> delete() =>
      _guardKeychain(() => _openStorage().delete(key: _key));

  static Future<String?> _read(FlutterSecureStorage storage) =>
      _guardKeychain(() => storage.read(key: _key));

  /// Maps the iOS "device not unlocked since boot" `OSStatus` onto
  /// [KeychainLockedException]. Every other [PlatformException] rethrows
  /// unchanged: an unknown keychain failure is not something we want to
  /// quietly interpret as either "locked" or "absent".
  static Future<T> _guardKeychain<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      if (isKeychainLocked(e)) throw const KeychainLockedException();
      rethrow;
    }
  }

  @visibleForTesting
  static void ensureKeyCanBeCreated({
    required bool hasDatabaseRequiringExistingKey,
  }) {
    if (hasDatabaseRequiringExistingKey) {
      throw const DatabaseKeyUnavailableException(
        'a database exists but its encryption key is gone',
      );
    }
  }

  /// Whether any existing database already needs the stored encryption
  /// key to be opened.
  ///
  /// A plaintext SQLite database is the expected upgrade input and is
  /// safe to pair with a newly-generated key: the storage layer will
  /// immediately migrate it in place. An encrypted file (or a file with
  /// an unknown/truncated header) is not safe to re-key, so it keeps the
  /// fail-closed behavior.
  static Future<bool> hasDatabaseRequiringExistingKey(
    Iterable<File> databases,
  ) async {
    for (final database in databases) {
      if (!await database.exists()) continue;
      final handle = await database.open();
      try {
        final header = await handle.read(16);
        if (header.length != 16 ||
            utf8.decode(header, allowMalformed: true) !=
                'SQLite format 3\u0000') {
          return true;
        }
      } finally {
        await handle.close();
      }
    }
    return false;
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
    final List<int> decoded;
    try {
      decoded = base64Url.decode(base64Url.normalize(key));
    } on FormatException {
      throw const DatabaseKeyUnavailableException(
        'stored database encryption key is not valid base64url',
      );
    }
    if (decoded.length != 32) {
      throw const DatabaseKeyUnavailableException(
        'stored database encryption key has the wrong length',
      );
    }
  }
}
