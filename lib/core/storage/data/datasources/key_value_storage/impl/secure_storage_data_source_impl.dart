import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:secrets/secrets.dart';

/// Legacy datasource adapter. Only the secrets package interacts with the OS keystore.
class SecureStorageDatasourceImpl implements KeyValueStorageDatasource<String> {
  final ApplicationStorage _storage;

  SecureStorageDatasourceImpl(this._storage);

  static Future<T> _unwrap<T>(
    Future<Result<T, SecretFailure>> operation,
  ) async => switch (await operation) {
    Ok(:final value) => value,
    Err(failure: KeystoreLockedFailure()) =>
      throw const KeychainLockedException(),
    Err(:final failure) => throw Exception(failure.logMessage),
  };

  @override
  Future<void> saveValue({required String key, required String value}) =>
      _unwrap(_storage.write(key: key, value: value));

  @override
  Future<Map<String, String>> getAll() => _unwrap(_storage.readAll());

  @override
  Future<String?> getValue(String key) => _unwrap(_storage.read(key));

  @override
  Future<bool> hasValue(String key) => _unwrap(_storage.contains(key));

  @override
  Future<void> deleteValue(String key) => _unwrap(_storage.delete(key));
}
