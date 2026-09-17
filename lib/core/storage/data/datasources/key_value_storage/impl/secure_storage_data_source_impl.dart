import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secrets/secrets.dart' show Secrets;

/// File-private operation labels for keychain refusal log lines.
/// Closed set so the impl can't drift into free-form strings.
enum _Operation { read, write, delete, contains, readAll }

/// iOS keychain `OSStatus` for `errSecInteractionNotAllowed`. Returned
/// by `SecItemCopyMatching` / `SecItemAdd` when the item's accessibility
/// class requires the device to be unlocked (or to have been unlocked
/// since boot) and the current state doesn't satisfy that. See
/// [KeychainLockedException].
const int _errSecInteractionNotAllowed = -25308;

class SecureStorageDatasourceImpl implements KeyValueStorageDatasource<String> {
  /// Prefixes owned by the `secrets` package: the seed namespace and the
  /// database keys it holds for other modules. The app shares an OS
  /// keystore with it but must not reach into either — seeds go through
  /// `Secrets`, database keys through `Secrets.databaseKey`. Taken from
  /// the package so the two lists cannot drift apart. Enforced here
  /// rather than left to convention, so a mistake fails loudly instead of
  /// quietly handling key material.
  static const _reserved = Secrets.reservedKeyPrefixes;

  final FlutterSecureStorage _storage;

  SecureStorageDatasourceImpl(this._storage);

  static bool _isReserved(String key) => _reserved.any(key.startsWith);

  void _refuseSecrets(String key, _Operation operation) {
    if (!_isReserved(key)) return;
    throw ArgumentError.value(
      key,
      'key',
      'belongs to the secrets package; use Secrets, not the shared '
          'store (${operation.name})',
    );
  }

  /// Wraps a keychain call, mapping iOS `-25308` to
  /// [KeychainLockedException] so callers can distinguish a
  /// temporarily-locked keychain from a missing key or other failure.
  /// Other [PlatformException]s rethrow unchanged.
  Future<T> _wrap<T>({
    required _Operation operation,
    String? key,
    required Future<T> Function() body,
  }) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      // Belt-and-suspenders: across `flutter_secure_storage` releases,
      // the OSStatus has historically appeared in `details` (current
      // fork), `code` (older versions, as a string), or embedded in
      // `message`. Match all three so a future fork bump that shifts
      // the field doesn't silently regress this whole class of
      // handling without a compile error.
      if (_isLocked(e)) {
        final target = key != null ? ' "$key"' : '';
        log.warning(
          'Device not unlocked since boot (${operation.name}$target)',
        );
        throw const KeychainLockedException();
      }
      rethrow;
    }
  }

  bool _isLocked(PlatformException e) =>
      e.details == _errSecInteractionNotAllowed ||
      e.code == '$_errSecInteractionNotAllowed' ||
      (e.message ?? '').contains('$_errSecInteractionNotAllowed');

  @override
  Future<void> saveValue({required String key, required String value}) {
    _refuseSecrets(key, _Operation.write);
    return _wrap(
      operation: _Operation.write,
      key: key,
      body: () => _storage.write(key: key, value: value),
    );
  }

  @override
  Future<Map<String, String>> getAll() async {
    final all = await _wrap(
      operation: _Operation.readAll,
      body: () => _storage.readAll(),
    );
    // Key material never reaches app code through this store, not even
    // to be ignored by the caller.
    return {
      for (final e in all.entries)
        if (!_isReserved(e.key)) e.key: e.value,
    };
  }

  @override
  Future<String?> getValue(String key) {
    _refuseSecrets(key, _Operation.read);
    return _wrap(
      operation: _Operation.read,
      key: key,
      body: () => _storage.read(key: key),
    );
  }

  @override
  Future<bool> hasValue(String key) {
    _refuseSecrets(key, _Operation.contains);
    return _wrap(
      operation: _Operation.contains,
      key: key,
      body: () => _storage.containsKey(key: key),
    );
  }

  @override
  Future<void> deleteValue(String key) {
    _refuseSecrets(key, _Operation.delete);
    return _wrap(
      operation: _Operation.delete,
      key: key,
      body: () => _storage.delete(key: key),
    );
  }
}
