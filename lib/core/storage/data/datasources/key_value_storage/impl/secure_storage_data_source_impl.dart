import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_v9/flutter_secure_storage_v9.dart'
    as fss_v9;

import '../../../../../utils/logger.dart';

class SecureStorageDatasourceImpl implements KeyValueStorageDatasource<String> {
  final FlutterSecureStorage _storage;
  final fss_v9.FlutterSecureStorageV9 _storageV9;

  SecureStorageDatasourceImpl(
    this._storage, {
    required fss_v9.FlutterSecureStorageV9 storageV9,
  }) : _storageV9 = storageV9;

  @override
  Future<void> saveValue({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      log.severe(
        message: 'Failed to write to secure storage v10',
        error: e,
        trace: StackTrace.current,
      );
      await _migrateFromV9Storage();
      await _storage.write(key: key, value: value);
    }
  }

  @override
  Future<Map<String, String>> getAll() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      log.severe(
        message: 'Failed to read from secure storage v10',
        error: e,
        trace: StackTrace.current,
      );
      await _migrateFromV9Storage();
      return await _storage.readAll();
    }
  }

  @override
  Future<String?> getValue(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      log.severe(
        message: 'Failed to read from secure storage v10',
        error: e,
        trace: StackTrace.current,
      );
      await _migrateFromV9Storage();
      return await _storage.read(key: key);
    }
  }

  @override
  Future<bool> hasValue(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      log.severe(
        message: 'Failed to check key in secure storage v10',
        error: e,
        trace: StackTrace.current,
      );
      await _migrateFromV9Storage();
      return await _storage.containsKey(key: key);
    }
  }

  @override
  Future<void> deleteValue(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      log.severe(
        message: 'Failed to delete key from secure storage v10',
        error: e,
        trace: StackTrace.current,
      );
      await _migrateFromV9Storage();
      await _storage.delete(key: key);
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      log.severe(
        message: 'Failed to delete all keys from secure storage v10',
        error: e,
        trace: StackTrace.current,
      );
      await _migrateFromV9Storage();
      await _storage.deleteAll();
    }
  }

  Future<void> _migrateFromV9Storage() async {
    log.info('Attempting to migrate from v9 to v10 secure storage');
    try {
      // Fallback to v9 storage if v10 fails
      final values = await _storageV9.readAll();
      if (values.isNotEmpty) {
        log.fine(
          'Found ${values.length} items in v9 storage, starting migration',
        );
        // We will just dump to file for now, as the migration is risky and
        //  we don't want to risk losing data for now
        await _dumpToFile(values);
        // Migrate values back to v10 storage
        /*for (final entry in values.entries) {
        await _storage.write(
          key: entry.key,
          value: entry.value,
          aOptions: AndroidOptions(resetOnError: true),
        );
      }*/
        // Try again to write to v10 after reset on error
        /*for (final entry in values.entries) {
        await _storage.write(
          key: entry.key,
          value: entry.value,
          aOptions: AndroidOptions(resetOnError: true),
        );
      }*/
      } else {
        log.warning(
          'No data found in v9 storage to migrate',
          error: Exception('Empty v9 storage'),
        );
      }
    } catch (e) {
      log.severe(
        message: 'Failed to read from v9',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  Future<void> _dumpToFile(Map<String, String> values) async {
    try {
      log.info('Dumping v9 storage to file for backup before migration');
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'secure_storage_v9_backup_$timestamp.json';

      final backup = {'timestamp': timestamp, 'values': values};
      final jsonString = json.encode(backup);
      final bytes = utf8.encode(jsonString);

      // Let user choose save location
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save secure storage backup',
        fileName: fileName,
        bytes: bytes,
      );

      if (outputFile == null) {
        log.info('User cancelled backup save');
        return;
      }

      log.fine('Backed up v9 storage to $outputFile');
    } catch (e) {
      log.severe(
        message: 'Failed to backup v9 storage',
        error: e,
        trace: StackTrace.current,
      );
    }
  }
}
