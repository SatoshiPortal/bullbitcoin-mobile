import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/domain/ports/secure_key_value_store_port.dart';

/// The ONLY code in `secrets` that touches the platform channel. Thin: it maps
/// `FlutterSecureStorage` to [SecureKeyValueStorePort] and translates a locked
/// keychain into [KeychainLockedException]. All logic lives above it in
/// `FssSecretStoreAdapter` (which is what the unit tests exercise via a fake).
class FlutterSecureStorageAdapter implements SecureKeyValueStorePort {
  FlutterSecureStorageAdapter(this._storage);

  /// Builds an instance configured for seed custody:
  ///  - `AfterFirstUnlockThisDeviceOnly` (background signing needs post-unlock;
  ///    `ThisDeviceOnly` blocks iCloud/Google backup of the seed),
  ///  - `resetOnError: false` — the SatoshiPortal fork defaults to `true`
  ///    ("permanently erase on error"), a seed-wipe footgun (dep-audit §11.2).
  ///
  /// Storage backend: this is fss10 (EncryptedSharedPreferences-OFF), which is
  /// the app's UNIVERSAL seed backend since the storage migration standardized
  /// every install on fss10 (`lib/core/storage/storage_locator.dart` verifies
  /// and persists a fss10 `SeedStoreType` flag on startup). So `.standard()` is
  /// correct for every user. The old fss9/ESP path
  /// (`flutter_secure_storage_legacy`) remains in the app only as a transitional
  /// fallback for a not-yet-migrated install; in the unlikely case one must be
  /// served, inject a matching `FlutterSecureStorage` instead of `.standard()`.
  factory FlutterSecureStorageAdapter.standard() {
    return FlutterSecureStorageAdapter(
      const FlutterSecureStorage(
        aOptions: AndroidOptions(
          resetOnError: false,
          keyCipherAlgorithm:
              KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
          storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      ),
    );
  }

  final FlutterSecureStorage _storage;

  Future<R> _guard<R>(Future<R> Function() op) async {
    try {
      return await op();
    } catch (e) {
      if (isKeychainLockedError(e)) {
        throw const KeychainLockedException();
      }
      rethrow;
    }
  }

  @override
  Future<String?> read(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => _guard(() => _storage.delete(key: key));

  @override
  Future<Map<String, String>> readAll() => _guard(_storage.readAll);

  @override
  Future<bool> containsKey(String key) =>
      _guard(() => _storage.containsKey(key: key));

  @override
  Future<void> deleteAll() => _guard(_storage.deleteAll);
}
