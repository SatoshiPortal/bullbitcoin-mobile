import 'dart:convert';
import 'dart:typed_data';

import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/ports/secure_key_value_store_port.dart';

/// Secure-storage key prefixes (mirrors the app's
/// `SecureStorageKeyPrefixConstants` + the legacy patterns migration 005 left
/// behind).
class SecretStoreKeys {
  static const seed = 'seed_';
  static const swap = 'swap_';

  /// Legacy artifacts that `keys()` must surface for reconciliation/purge:
  /// pre-0.4 seeds stored under a raw 8-hex fingerprint (no prefix), the Hive
  /// encryption key, and per-swap sensitive blobs.
  static const legacyHiveEncryption = 'hiveEncryptionKey';
  static const legacySwapTxSensitivePrefix = 'swapTxSensitive_';
  static final legacyRawFingerprint = RegExp(r'^[0-9a-f]{8}$');

  static String seedKey(String fingerprintHex) => '$seed$fingerprintHex';

  /// Whether [key] is (or was, legacy) a seed-bearing key.
  static bool isSeedKey(String key) =>
      key.startsWith(seed) || legacyRawFingerprint.hasMatch(key);
}

/// The only [SecretStorePort] backend today: adapts `flutter_secure_storage`.
///
/// Replicates the live `seed_datasource` behavior: 5-attempt exponential
/// backoff on transient null reads, [KeychainLockedException] rethrown (never
/// converted to not-found), `resetOnError: false` (configured in the adapter).
/// Stores bytes as base64; never logs values.
class FssSecretStoreAdapter implements SecretStorePort {
  FssSecretStoreAdapter(
    this._kv, {
    this._maxReadRetries = 5,
    this._initialRetryDelay = const Duration(milliseconds: 300),
  });

  final SecureKeyValueStorePort _kv;
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
      final isLast = attempt == _maxReadRetries - 1;
      String? value;
      try {
        value = await _kv.read(key);
      } on KeychainLockedException {
        // Retrying cannot help — the lock clears only on user unlock. Rethrow
        // so the boundary surfaces KeychainLockedFailure, never not-found.
        rethrow;
      } on Exception {
        // A TRANSIENT platform/channel error (not a lock) — retry with backoff
        // before giving up, matching the live datasource's resilience. Rethrow
        // on the last attempt so it surfaces as a typed failure (never silently
        // a not-found).
        if (isLast) rethrow;
        await Future<void>.delayed(delay);
        delay *= 2;
        continue;
      }

      if (value != null) {
        // Zero the decoded plaintext after `use`, matching oubliette's
        // base-class hygiene. The `await` is mandatory — without it the
        // `finally` would zero the buffer before the async callback runs and
        // hand `use` all-zero bytes. (The underlying base64 String from the
        // channel is immutable and unzeroable — the string-vs-bytes limit
        // oubliette exists to fix; zeroing the decoded Uint8List is the best FSS
        // can do. Relies on `use`/`Mnemonic.fromStorageBytes` not retaining a
        // view past return — the same invariant oubliette already depends on.)
        final bytes = _decode(value);
        try {
          return await use(bytes);
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
      }
      if (!isLast) {
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }
    // Every attempt read null. Distinguish GONE from a DEGRADED read: if the key
    // still exists in the keystore but persistently reads null, the seed is NOT
    // missing — the backend is in a locked/degraded state (post-restore, keyring
    // not yet unlocked, an OEM keystore hiccup). Reporting SecretNotFound there
    // would break the locked≠missing invariant and tell the user their seed is
    // gone. Surface it as locked (retryable), not not-found. Only when the key
    // genuinely does not exist do we report not-found.
    if (await _kv.containsKey(key)) {
      throw KeychainLockedException(
          'key exists but read null $_maxReadRetries times — degraded/locked');
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

  /// Wipes only the SEED keys this store owns (`seed_*` + legacy raw-fingerprint
  /// blobs) — NOT the whole secure-storage namespace. The package shares the
  /// keychain with the app (`swap_*` KeyPairs, the Hive encryption key, the PIN/
  /// api-key); a blind `deleteAll` here would destroy app-owned secrets and
  /// brick in-flight swaps. Deleting those is the app's responsibility.
  @override
  Future<void> purge() async {
    for (final key in await keys()) {
      if (SecretStoreKeys.isSeedKey(key)) {
        await _kv.delete(key);
      }
    }
  }

  /// NOTE (plaintext residency): `flutter_secure_storage` offers no keys-only
  /// enumeration, so `readAll()` decrypts EVERY stored value into unwipeable
  /// heap `String`s just to read the key names — on each startup reconcile and
  /// migration census. We discard the values immediately (return only the keys),
  /// but the plaintext transits the moving-GC heap and cannot be zeroed (the
  /// same String-vs-bytes limit the hardware backend exists to fix). Shrinking
  /// this awaits a keys-only platform API; documented, not yet avoidable.
  @override
  Future<List<String>> keys() async {
    final all = await _kv.readAll();
    return all.keys.toList(growable: false);
  }
}
