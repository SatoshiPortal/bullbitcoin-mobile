import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_v9/flutter_secure_storage_v9.dart'
    as fss_v9;

import '../../../utils/logger.dart';

class MigrationSecureStorageDatasource {
  final FlutterSecureStorage _storage;

  final fss_v9.FlutterSecureStorageV9 _storageV9;

  MigrationSecureStorageDatasource(
    this._storage, {
    required fss_v9.FlutterSecureStorageV9 storageV9,
  }) : _storageV9 = storageV9;

  Future<void> store({required String key, required String value}) async {
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

  Future<String?> fetch({required String key}) async {
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

  Future<OldSeed> oldSeedFetch(String fingerprint) async {
    try {
      return await _oldSeedFetch(fingerprint);
    } catch (e) {
      log.severe(
        message: 'Failed to fetch old seed from v9 storage',
        error: e,
        trace: StackTrace.current,
      );
      await _migrateFromV9Storage();
      return await _oldSeedFetch(fingerprint);
    }
  }

  Future<OldSeed> _oldSeedFetch(String fingerprint) async {
    final jsn = await _storage.read(key: fingerprint);
    if (jsn == null) throw Exception('No seed found');
    final obj = json.decode(jsn) as Map<String, dynamic>;
    final seed = OldSeed.fromJson(obj);
    seed.mnemonicFingerprint;
    return seed;
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
