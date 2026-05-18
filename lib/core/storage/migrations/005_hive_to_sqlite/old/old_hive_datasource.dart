import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:hive/hive.dart' show Box, Hive, HiveAesCipher;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

class OldHiveDatasource {
  final KeyValueStorageDatasource<String> _secureStorage;

  /// Cached Future of the open box. Storing the Future (not the resolved
  /// Box) makes [_ensureBox] safe under concurrent first-callers without
  /// a mutex: both callers observe the same in-flight Future and the
  /// keychain read + `Hive.openBox` call happens exactly once. Hive
  /// itself also serializes concurrent opens internally
  /// (`hive_impl.dart:_openingBoxes`), but caching the Future avoids the
  /// redundant `_secureStorage.getValue` call.
  Future<Box<dynamic>>? _boxFuture;

  OldHiveDatasource(this._secureStorage);

  /// Opens the legacy Hive box on first access and caches the open
  /// Future. Deferred so the keychain read for the Hive encryption key
  /// only fires when a migration path actually needs old data — never
  /// during DI bootstrap. Previously eager in
  /// `StorageLocator.registerDatasources`, which threw
  /// `PlatformException(-25308)` on iOS pre-first-unlock launches and
  /// crashed every background pre-warmed app spawn.
  ///
  /// If the open fails (e.g. `KeychainLockedException` because the
  /// device hasn't been unlocked since boot, or a transient Hive
  /// error), the cache is cleared so a subsequent call retries from
  /// scratch. Without this clear, any later `_ensureBox` would return
  /// the same rejected Future — preventing user-driven retries (e.g.
  /// the Legacy Seed Viewer re-fetching after an error) from
  /// succeeding within the same app session. Migration paths abort on
  /// first error regardless, so they don't benefit directly, but this
  /// keeps the cache contract honest: successful opens are cached,
  /// failures aren't.
  Future<Box<dynamic>> _ensureBox() => _boxFuture ??= _openBoxClearOnError();

  /// Wraps [_openBox] so a failed open clears [_boxFuture]. The cache
  /// reset happens *inside* the same Future the caller awaits — no
  /// secondary `catchError`-derived Future, so no unhandled-error
  /// warning when callers handle the failure themselves.
  Future<Box<dynamic>> _openBoxClearOnError() async {
    try {
      return await _openBox();
    } catch (_) {
      _boxFuture = null;
      rethrow;
    }
  }

  Future<Box<dynamic>> _openBox() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    final password = await _secureStorage.getValue(
      OldStorageKeys.hiveEncryption.name,
    );

    if (password == null) {
      return await Hive.openBox('store');
    }
    final cipher = HiveAesCipher(base64Url.decode(password));
    return await Hive.openBox('store', encryptionCipher: cipher);
  }

  Future<String?> getValue(String key) async {
    if (_isHiveLegacyImpossible) return null;
    final box = await _ensureBox();
    return box.get(key) as String?;
  }

  Future<void> saveValue({required String key, required String value}) async {
    if (_isHiveLegacyImpossible) return;
    final box = await _ensureBox();
    await box.put(key, value);
  }

  /// Android is the ONLY platform that ever shipped a BULL release with
  /// Hive as the storage backend (v0.1-v0.4, 2023-2024). Real Android
  /// users may still be sitting on legacy Hive data awaiting v5
  /// migration, so Android gets the real implementation.
  ///
  /// Every other platform — iOS, macOS, web, Linux, Windows — released
  /// after the v5.0 Hive→SQLite migration (iOS substantive releases
  /// began at v5.3 in June 2025), so no install on those platforms can
  /// hold legacy Hive data. Short-circuiting non-Android:
  ///  - eliminates the keychain read for the Hive encryption key
  ///    (the legacy v4/v5 migration paths' main pre-unlock failure
  ///    surface on iOS)
  ///  - prevents the lazy box open from running, making
  ///    `KeychainLockedException` impossible from this code path
  ///  - is functionally identical to what the migration paths already
  ///    do when `getValue` returns `null` — they treat it as "no
  ///    legacy data" and skip the rest of the migration
  bool get _isHiveLegacyImpossible => !Platform.isAndroid;
}
