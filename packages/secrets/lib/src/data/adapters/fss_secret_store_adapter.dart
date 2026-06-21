import 'dart:convert';
import 'dart:typed_data';

import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/storage/secret_store.dart';
import 'package:secrets/src/storage/secure_key_value_store.dart';

/// Secure-storage key prefixes (mirrors the app's
/// `SecureStorageKeyPrefixConstants` + the legacy patterns migration 005 left
/// behind).
class SecretStoreKeys {
  static const seed = 'seed_';
  static const swap = 'swap_';

  /// Legacy artifacts that `keys()` must surface for reconciliation/purge:
  /// pre-0.4 seeds stored under a raw 8-hex fingerprint (no prefix), the Hive
  /// encryption key, and per-swap sensitive blobs.
  static const legacyHiveEncryption = 'hiveEncryption';
  static const legacySwapTxSensitivePrefix = 'swapTxSensitive_';
  static final legacyRawFingerprint = RegExp(r'^[0-9a-f]{8}$');

  static String seedKey(String fingerprintHex) => '$seed$fingerprintHex';

  /// Whether [key] is (or was, legacy) a seed-bearing key.
  static bool isSeedKey(String key) =>
      key.startsWith(seed) || legacyRawFingerprint.hasMatch(key);
}

/// The only [SecretStore] backend today: adapts `flutter_secure_storage`.
///
/// Replicates the live `seed_datasource` behavior: 5-attempt exponential
/// backoff on transient null reads, [KeychainLockedException] rethrown (never
/// converted to not-found), `resetOnError: false` (configured in the adapter).
/// Stores bytes as base64; never logs values.
class FssSecretStore implements SecretStore {
  FssSecretStore(
    this._kv, {
    int maxReadRetries = 5,
    Duration initialRetryDelay = const Duration(milliseconds: 300),
  })  : _maxReadRetries = maxReadRetries,
        _initialRetryDelay = initialRetryDelay;

  final SecureKeyValueStore _kv;
  final int _maxReadRetries;
  final Duration _initialRetryDelay;

  @override
  Future<void> init() async {/* FSS needs no init */}

  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
        hardwareBacked: false, // OS keystore; not a guaranteed HSM
        thisDeviceOnly: true, // AfterFirstUnlockThisDeviceOnly
        syncable: false,
      );

  @override
  Future<bool> exists(String key) => _kv.containsKey(key);

  /// Version tag on values written by THIS class, so [_decode] is deterministic
  /// (no base64-vs-raw guessing). Legacy values have no tag → decoded as raw.
  static const _v1Prefix = 's1:';

  @override
  Future<void> store(String key, Uint8List value) async {
    if (await _kv.containsKey(key)) {
      throw SecretAlreadyExistsException(key);
    }
    await _kv.write(key, '$_v1Prefix${base64.encode(value)}');
  }

  @override
  Future<R> useAndForget<R>(
      String key, Future<R> Function(Uint8List bytes) use) async {
    var delay = _initialRetryDelay;
    for (var attempt = 0; attempt < _maxReadRetries; attempt++) {
      String? value;
      try {
        value = await _kv.read(key);
      } on KeychainLockedException {
        // Retrying cannot help — the lock clears only on user unlock. Rethrow
        // so the boundary surfaces KeychainLockedFailure, never not-found.
        rethrow;
      }

      if (value != null) {
        return use(_decode(value));
      }
      if (attempt < _maxReadRetries - 1) {
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }
    throw SecretNotFoundException(key);
  }

  /// Decodes a stored value DETERMINISTICALLY by its version tag (avoids
  /// guessing base64-vs-raw, which could mis-decode a legacy value that happens
  /// to be base64-shaped). A value written by [store] carries [_v1Prefix] and
  /// is base64; anything else is a LEGACY value (pre-0.4 raw-fingerprint seeds,
  /// stored as raw UTF-8 / JSON) and is returned as raw UTF-8 bytes.
  Uint8List _decode(String value) {
    if (value.startsWith(_v1Prefix)) {
      return Uint8List.fromList(
          base64.decode(value.substring(_v1Prefix.length)));
    }
    return Uint8List.fromList(utf8.encode(value));
  }

  @override
  Future<void> trash(String key) => _kv.delete(key);

  @override
  Future<void> purge() => _kv.deleteAll();

  @override
  Future<List<String>> keys() async {
    final all = await _kv.readAll();
    return all.keys.toList(growable: false);
  }
}
