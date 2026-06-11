import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage_legacy/flutter_secure_storage.dart';

/// File-private operation labels — twin of the enum in
/// `secure_storage_data_source_impl.dart`. Duplicated because the
/// fss9 and fss10 plugins expose distinct `PlatformException` types
/// and the two impls share no code.
enum _Operation { read, write, delete, contains, readAll, deleteAll }

/// See [_errSecInteractionNotAllowed] in
/// `secure_storage_data_source_impl.dart`. Duplicated here because the
/// fss9 and fss10 plugins expose distinct `PlatformException` types and
/// can't share a single wrapper without coupling the impls.
const int _errSecInteractionNotAllowed = -25308;

class SecureStorageLegacyDatasourceImpl
    implements KeyValueStorageDatasource<String> {
  final FlutterSecureStorage _storage;

  SecureStorageLegacyDatasourceImpl(this._storage);

  Future<T> _wrap<T>({
    required _Operation operation,
    String? key,
    required Future<T> Function() body,
  }) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      // See note in `secure_storage_data_source_impl.dart` `_isLocked`
      // — the OSStatus field has shifted across fss releases, so we
      // check `details` / `code` / `message` all three.
      if (_isLocked(e)) {
        final target = key != null ? ' "$key"' : '';
        log.warning(
          'Device not unlocked since boot '
          '(legacy/fss9, ${operation.name}$target)',
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
    return _wrap(
      operation: _Operation.write,
      key: key,
      body: () => _storage.write(key: key, value: value),
    );
  }

  @override
  Future<Map<String, String>> getAll() {
    return _wrap(operation: _Operation.readAll, body: () => _storage.readAll());
  }

  @override
  Future<String?> getValue(String key) {
    return _wrap(
      operation: _Operation.read,
      key: key,
      body: () => _storage.read(key: key),
    );
  }

  @override
  Future<bool> hasValue(String key) {
    return _wrap(
      operation: _Operation.contains,
      key: key,
      body: () => _storage.containsKey(key: key),
    );
  }

  @override
  Future<void> deleteValue(String key) {
    return _wrap(
      operation: _Operation.delete,
      key: key,
      body: () => _storage.delete(key: key),
    );
  }

  @override
  Future<void> deleteAll() {
    return _wrap(
      operation: _Operation.deleteAll,
      body: () => _storage.deleteAll(),
    );
  }
}
