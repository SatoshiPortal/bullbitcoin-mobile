import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;

import '../domain/entities/recoverbull_network.dart';
import '../domain/recoverbull_lifecycle_port.dart';
import 'recoverbull_database.dart';

/// Owns the one connection to the RecoverBull database: opening, corruption
/// recovery, reset and disposal.
final class RecoverBullLifecycle implements RecoverBullLifecyclePort {
  static const _sqliteCorrupt = 11;
  static const _sqliteNotADatabase = 26;

  final LogSink? _log;
  RecoverBullDatabase? _database;
  String? _path;
  Future<RecoverBullDatabase>? _opening;
  String? _openingPath;
  bool _disposed = false;

  RecoverBullLifecycle({this._log});

  Future<void> open(
    String path, {
    bool initialPermissionGranted = false,
    Uri? initialServerUrlOverride,
  }) async {
    await _openDatabase(
      path,
      initialPermissionGranted: initialPermissionGranted,
      initialServerUrlOverride: initialServerUrlOverride?.toString(),
    );
  }

  Future<RecoverBullDatabase> openDatabase(
    String path, {
    bool initialPermissionGranted = false,
    Uri? initialServerUrlOverride,
  }) => _openDatabase(
    path,
    initialPermissionGranted: initialPermissionGranted,
    initialServerUrlOverride: initialServerUrlOverride?.toString(),
  );

  /// Returns the open connection for [path], sharing one in-flight open
  /// between concurrent first callers so they never race two connections.
  Future<RecoverBullDatabase> _openDatabase(
    String path, {
    bool initialPermissionGranted = false,
    String? initialServerUrlOverride,
  }) async {
    while (true) {
      if (_disposed) throw StateError('RecoverBull lifecycle is disposed');
      final database = _database;
      if (database != null && _path == path) return database;
      final opening = _opening;
      if (opening == null) break;
      if (_openingPath == path) return opening;
      try {
        await opening;
      } catch (_) {}
    }
    late final Future<RecoverBullDatabase> future;
    future =
        _replaceDatabase(
          path,
          initialPermissionGranted: initialPermissionGranted,
          initialServerUrlOverride: initialServerUrlOverride,
        ).whenComplete(() {
          if (identical(_opening, future)) {
            _opening = null;
            _openingPath = null;
          }
        });
    _opening = future;
    _openingPath = path;
    return future;
  }

  Future<RecoverBullDatabase> _replaceDatabase(
    String path, {
    required bool initialPermissionGranted,
    required String? initialServerUrlOverride,
  }) async {
    final previous = _database;
    if (previous != null) {
      _database = null;
      _path = null;
      await previous.close();
    }
    RecoverBullDatabase? database;
    try {
      database = RecoverBullDatabase.open(
        path,
        initialPermissionGranted: initialPermissionGranted,
        initialServerUrlOverride: initialServerUrlOverride,
      );
      await database.forceOpen();
    } catch (error) {
      await _closeQuietly(database);
      if (!_isCorruption(error)) rethrow;
      await _archiveCorruptFiles(path);
      _log?.warning('recoverbull.database.corrupt_archived');
      database = RecoverBullDatabase.open(
        path,
        initialPermissionGranted: initialPermissionGranted,
        initialServerUrlOverride: initialServerUrlOverride,
        initialBackupStatusLost: true,
      );
      try {
        await database.forceOpen();
      } catch (_) {
        await _closeQuietly(database);
        rethrow;
      }
    }
    if (_disposed) {
      await database.close();
      throw StateError('RecoverBull lifecycle is disposed');
    }
    _database = database;
    _path = path;
    return database;
  }

  static Future<void> _closeQuietly(RecoverBullDatabase? database) async {
    try {
      await database?.close();
    } catch (_) {}
  }

  static bool _isCorruption(Object error) {
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    if (cause is RecoverBullDatabaseIntegrityException) return true;
    return cause is SqliteException &&
        (cause.resultCode == _sqliteCorrupt ||
            cause.resultCode == _sqliteNotADatabase);
  }

  Future<void> dispose() async {
    final database = _database;
    _database = null;
    _path = null;
    if (database != null) await database.close();
    _disposed = true;
  }

  Future<void> reset(String path) async {
    await dispose();
    await _deleteFiles(path);
    _disposed = false;
  }

  Future<void> resetConfigured() async {
    final path = _path;
    if (path != null) await reset(path);
  }

  @override
  Future<void> markStored(RecoverBullNetwork network) async =>
      (await _openDatabase(_requirePath())).markEncryptedBackupStored(network);

  @override
  Future<void> markVerified(RecoverBullNetwork network) async =>
      (await _openDatabase(
        _requirePath(),
      )).markEncryptedBackupVerified(network);

  String _requirePath() {
    final path = _path;
    if (_disposed || path == null) {
      throw StateError('RecoverBull lifecycle is disposed or unopened');
    }
    return path;
  }

  static Future<void> _deleteFiles(String path) async {
    for (final suffix in ['', '-wal', '-shm', '-journal', '.sqlite-journal']) {
      final file = File('$path$suffix');
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  static Future<void> _archiveCorruptFiles(String path) async {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final archivePath = '$path.corrupt-$timestamp';
    final directory = Directory(File(path).parent.path);
    final prefix = '${File(path).uri.pathSegments.last}.corrupt-';
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File && entity.uri.pathSegments.last.startsWith(prefix)) {
          await entity.delete();
        }
      }
    }
    for (final suffix in ['', '-wal', '-shm', '-journal', '.sqlite-journal']) {
      final file = File('$path$suffix');
      if (await file.exists()) await file.rename('$archivePath$suffix');
    }
  }
}
