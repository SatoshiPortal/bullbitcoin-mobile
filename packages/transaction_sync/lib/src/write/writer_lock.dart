import 'lease_diagnostics.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import '../domain/transaction_sync_failure.dart';
import '../domain/wallet_key.dart';
import 'native_store_paths.dart';

/// Only package:sqlite3 may open these files. Never unlink them, including on
/// wallet deletion. Acquire in the isolate awaiting the actual native work.
/// sqlite3 2.9.4 uses a Dart Finalizer: killing the holder leaks the connection
/// until process exit. Upgrading sqlite3 requires repeating the teardown tests.
final class WriterLock {
  // Measured holds: cache 10 ms, hydrate 131 ms, sync 266 ms; allow 1 s without blocking the UI isolate.
  static const writerWaitLimit = Duration(milliseconds: 1000);
  static const _retryStepsMs = [10, 20, 50, 100];

  final Database _db;
  bool _released = false;
  final LeaseDiagnostics _diagnostics;
  final Stopwatch _held = Stopwatch()..start();

  WriterLock._(this._db, this._diagnostics);

  static Result<WriterLock, TransactionSyncFailure> acquire(
    String documentsDirectory,
    WalletKey key, {
    LeaseDiagnostics? diagnostics,
  }) {
    final trace =
        diagnostics ??
        LeaseDiagnostics.current ??
        LeaseDiagnostics(role: LeaseRole.writer, intent: LeaseIntent.sync);
    final path = writerLockPath(documentsDirectory, key);
    if (path case Err(:final failure)) return Err(failure);
    var busySource = LeaseBusySource.leaseOpen;
    Database? db;
    try {
      db = _open((path as Ok<String, TransactionSyncFailure>).value);
      if (db == null) return const Err(TransactionSyncStorageFailure());
      busySource = LeaseBusySource.leaseBegin;
      db.execute('BEGIN IMMEDIATE');
      final lock = WriterLock._(db, trace);
      trace.acquire();
      return Ok(lock);
    } on SqliteException catch (error) {
      db?.dispose();
      if (error.resultCode == 5) trace.busy(busySource);
      return Err(
        error.resultCode == 5
            ? const TransactionSyncBusyFailure()
            : const TransactionSyncStorageFailure(),
      );
    } on FileSystemException {
      db?.dispose();
      return const Err(TransactionSyncStorageFailure());
    }
  }

  /// Writer-only admission. Readers use [acquire] and never wait.
  static Future<Result<WriterLock, TransactionSyncFailure>> acquireWriter(
    String documentsDirectory,
    WalletKey key, {
    required LeaseDiagnostics diagnostics,
  }) async {
    final path = writerLockPath(documentsDirectory, key);
    if (path case Err(:final failure)) return Err(failure);
    Database? db;
    var busySource = LeaseBusySource.leaseOpen;
    final waited = Stopwatch();
    try {
      db = _open((path as Ok<String, TransactionSyncFailure>).value);
      if (db == null) return const Err(TransactionSyncStorageFailure());
      final connection = db;
      busySource = LeaseBusySource.leaseBegin;
      waited.start();
      var step = 0;
      while (true) {
        try {
          connection.execute('BEGIN IMMEDIATE');
          final lock = WriterLock._(connection, diagnostics);
          db = null; // The lease owns the connection from this point onward.
          diagnostics.acquire(waitedMs: waited.elapsedMilliseconds);
          return Ok(lock);
        } on SqliteException catch (error) {
          if (error.resultCode != 5) rethrow;
        }
        final remaining = writerWaitLimit - waited.elapsed;
        if (remaining <= Duration.zero) {
          diagnostics.busy(busySource, waitedMs: waited.elapsedMilliseconds);
          return const Err(TransactionSyncBusyFailure());
        }
        final delay = Duration(milliseconds: _retryStepsMs[step]);
        await Future<void>.delayed(delay < remaining ? delay : remaining);
        step = math.min(step + 1, _retryStepsMs.length - 1);
        // Even a late wakeup gets one final non-blocking acquisition attempt.
      }
    } on SqliteException catch (error) {
      if (error.resultCode == 5) {
        diagnostics.busy(busySource, waitedMs: waited.elapsedMilliseconds);
      }
      return Err(
        error.resultCode == 5
            ? const TransactionSyncBusyFailure()
            : const TransactionSyncStorageFailure(),
      );
    } on FileSystemException {
      return const Err(TransactionSyncStorageFailure());
    } finally {
      db?.dispose();
    }
  }

  static Database? _open(String path) {
    File(path).parent.createSync(recursive: true);
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA busy_timeout = 0');
      // Refuse an unexpected journal configuration; no WAL lock semantics.
      if (db.select('PRAGMA journal_mode').single.values.single == 'delete') {
        return db;
      }
    } on Object {
      db.dispose();
      rethrow;
    }
    db.dispose();
    return null;
  }

  /// Call only after all native futures have settled. No timeout or cancellation
  /// wrapper may release a lease around an unfinished FRB operation.
  void release() {
    if (_released) return;
    try {
      _db.execute('ROLLBACK');
    } finally {
      _released = true;
      try {
        _db.dispose();
      } finally {
        _diagnostics.release(_held.elapsedMilliseconds);
      }
    }
  }
}
