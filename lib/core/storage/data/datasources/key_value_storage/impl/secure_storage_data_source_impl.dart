import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_v9/flutter_secure_storage_v9.dart'
    hide AndroidOptions;

import '../../../../../utils/logger.dart';

class SecureStorageDatasourceImpl implements KeyValueStorageDatasource<String> {
  final FlutterSecureStorage _storage;
  final FlutterSecureStorageV9 _storageV9;

  SecureStorageDatasourceImpl(
    this._storage, {
    required FlutterSecureStorageV9 storageV9,
  }) : _storageV9 = storageV9;

  Future<void> _migrateFromV9Storage() async {
    // Fallback to v9 storage if v10 fails
    final values = await _storageV9.readAll();
    if (values.isNotEmpty) {
      // Migrate values back to v10 storage
      for (final entry in values.entries) {
        await _storage.write(
          key: entry.key,
          value: entry.value,
          aOptions: AndroidOptions(resetOnError: true),
        );
      }
    }
  }

  @override
  Future<void> saveValue({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      await _migrateFromV9Storage();
      await _storage.write(key: key, value: value);
    }
  }

  @override
  Future<Map<String, String>> getAll() async {
    try {
      return _storage.readAll();
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      await _migrateFromV9Storage();
      // Return from the v10 storage after migration to be sure the migration was successful
      return _storage.readAll();
    }
  }

  @override
  Future<String?> getValue(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      await _migrateFromV9Storage();
      return await _storage.read(key: key);
    }
  }

  @override
  Future<bool> hasValue(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      await _migrateFromV9Storage();
      return await _storage.containsKey(key: key);
    }
  }

  @override
  Future<void> deleteValue(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      await _migrateFromV9Storage();
      await _storage.delete(key: key);
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      await _migrateFromV9Storage();
      await _storage.deleteAll();
    }
  }
}
