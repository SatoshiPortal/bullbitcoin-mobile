import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException, NativeDatabase;

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
  final List<FutureOr<void> Function()> _beforeDispose = [];

  RecoverBullLifecycle({this._log});

  bool get isDisposed => _disposed;

  /// Registers owned resources that must stop before the database closes.
  void registerBeforeDispose(FutureOr<void> Function() action) {
    if (_disposed) throw StateError('RecoverBull lifecycle is disposed');
    _beforeDispose.add(action);
  }

  /// A user-confirmed recovery session when durable storage cannot open.
  /// Never touches the unavailable file or imports its unverified consent.
  Future<RecoverBullDatabase> openTemporary() async {
    if (_disposed || _opening != null || _database != null) {
      throw StateError('Temporary storage requires an unopened lifecycle');
    }
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    try {
      await database.ensureState(initialBackupStatusLost: true);
      await database.customStatement(
        'UPDATE recoverbull_state SET attempt_monitoring_enabled = 0',
      );
    } on Exception {
      await database.close();
      rethrow;
    }
    _database = database;
    _path = null;
    return database;
  }

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
    if (_disposed) return;
    _disposed = true;
    final database = _database;
    _database = null;
    _path = null;
    final hooks = List.of(_beforeDispose);
    _beforeDispose.clear();
    try {
      for (final hook in hooks) {
        try {
          await hook();
        } on Exception {
          _log?.warning('recoverbull.lifecycle.resource_close_failed');
        }
      }
    } finally {
      if (database != null) await database.close();
    }
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
  Future<void> markStored(RecoverBullNetwork network) async {
    if (_disposed) return;
    final database = _database;
    if (database == null) throw StateError('RecoverBull lifecycle is unopened');
    await database.markEncryptedBackupStored(network);
  }

  @override
  Future<void> markVerified(RecoverBullNetwork network) async {
    if (_disposed) return;
    final database = _database;
    if (database == null) throw StateError('RecoverBull lifecycle is unopened');
    await database.markEncryptedBackupVerified(network);
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
