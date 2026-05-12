import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage_legacy/flutter_secure_storage.dart';

/// Operation kind used by secure-storage datasources to label
/// warning log lines when the keychain refuses an operation. Kept as
/// an enum (rather than free-form strings) so the impls share a
/// closed set of operation labels without each one inventing its
/// own.
enum Operation { read, write, delete, contains, readAll, deleteAll }

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
    required Operation operation,
    String? key,
    required Future<T> Function() body,
  }) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      if (e.details == _errSecInteractionNotAllowed) {
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

  @override
  Future<void> saveValue({required String key, required String value}) {
    return _wrap(
      operation: Operation.write,
      key: key,
      body: () => _storage.write(key: key, value: value),
    );
  }

  @override
  Future<Map<String, String>> getAll() {
    return _wrap(operation: Operation.readAll, body: () => _storage.readAll());
  }

  @override
  Future<String?> getValue(String key) {
    return _wrap(
      operation: Operation.read,
      key: key,
      body: () => _storage.read(key: key),
    );
  }

  @override
  Future<bool> hasValue(String key) {
    return _wrap(
      operation: Operation.contains,
      key: key,
      body: () => _storage.containsKey(key: key),
    );
  }

  @override
  Future<void> deleteValue(String key) {
    return _wrap(
      operation: Operation.delete,
      key: key,
      body: () => _storage.delete(key: key),
    );
  }

  @override
  Future<void> deleteAll() {
    return _wrap(
      operation: Operation.deleteAll,
      body: () => _storage.deleteAll(),
    );
  }
}
