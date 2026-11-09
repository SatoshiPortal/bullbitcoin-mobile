import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show NativeDatabase, SqliteException;

import 'recoverbull_database.dart';

/// Owns a single connection and preserves unavailable or future databases.
final class RecoverBullStorage {
  final String path;
  Future<RecoverBullDatabase>? _opening;
  RecoverBullDatabase? _database;
  bool _disposed = false;
  bool _temporary = false;

  RecoverBullStorage(this.path);

  bool get isTemporary => _temporary;

  Future<RecoverBullDatabase> open() {
    if (_disposed) throw StateError('RecoverBull storage is disposed');
    final database = _database;
    if (database != null) return Future.value(database);
    return _opening ??= _open().whenComplete(() {
      if (_database == null) _opening = null;
    });
  }

  Future<RecoverBullDatabase> _open() async {
    var database = RecoverBullDatabase.open(path);
    try {
      await database.forceOpen();
    } catch (error) {
      await database.close();
      if (!_isCorruption(error)) {
        _opening = null;
        rethrow;
      }
      final archive =
          '$path.corrupt-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final file = File('$path$suffix');
        if (await file.exists()) await file.rename('$archive$suffix');
      }
      log.warning('recoverbull corrupt metadata archived');
      database = RecoverBullDatabase.open(path);
      try {
        await database.forceOpen();
        // The destroyed feature state may have superseded the old root
        // settings. Do not silently resurrect its URL or consent.
        await database.customStatement(
          'UPDATE recoverbull_state SET legacy_import_complete = 1',
        );
      } catch (_) {
        await database.close();
        _opening = null;
        rethrow;
      }
    }
    return _accept(database);
  }

  /// Only after a failed durable open and an explicit user recovery choice.
  Future<RecoverBullDatabase> openTemporary() async {
    if (_disposed || _opening != null || _database != null) {
      throw StateError('Temporary recovery requires unopened storage');
    }
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    try {
      await database.forceOpen();
      await database.customStatement(
        'UPDATE recoverbull_state SET monitoring_enabled = 0',
      );
    } catch (_) {
      await database.close();
      rethrow;
    }
    _temporary = true;
    return _accept(database);
  }

  Future<RecoverBullDatabase> _accept(RecoverBullDatabase database) async {
    if (_disposed) {
      await database.close();
      throw StateError('RecoverBull storage is disposed');
    }
    _database = database;
    return database;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final database = _database;
    _database = null;
    if (database != null) await database.close();
    // An in-flight open observes _disposed and closes its own connection.
  }

  static bool _isCorruption(Object error) {
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    return cause is RecoverBullDatabaseIntegrityException ||
        (cause is SqliteException &&
            (cause.resultCode == 11 || cause.resultCode == 26));
  }
}
