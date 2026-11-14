import 'lease_diagnostics.dart';

import 'dart:ffi' show Pointer;
import 'dart:io';
import 'dart:math' as math;

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../transaction_sync.dart';

/// Only package:sqlite3 may open these files. Never unlink them, including on
/// wallet deletion. Acquire in the isolate awaiting the actual native work.
/// A Dart finalizer owns the connection: killing the holder keeps it open until
/// process exit, so a native operation outliving its isolate keeps its lease.
final class WriterLock {
  static final _databaseFinalizer = Finalizer<Pointer<void>>(_closeHandle);

  // Measured holds: cache 10 ms, hydrate 131 ms, sync 266 ms; allow 1 s without blocking the UI isolate.
  static const writerWaitLimit = Duration(milliseconds: 1000);
  static const _retryStepsMs = [10, 20, 50, 100];

  final Database _db;
  bool _released = false;
  final LeaseDiagnostics _diagnostics;
  final Stopwatch _held = Stopwatch()..start();

  WriterLock._(this._db, this._diagnostics);

  static String path(String directory, WalletKey key) {
    final id = key.id.codeUnits
        .map((unit) => unit.toRadixString(16).padLeft(4, '0'))
        .join();
    final chain = switch (key.network) {
      BitcoinNetwork() => 'bitcoin',
      LiquidNetwork() => 'liquid',
    };
    return '$directory/$chain-${key.network.env.name}-$id.lock.sqlite';
  }

  static Result<WriterLock, TransactionSyncFailure> acquire(
    String directory,
    WalletKey key, {
    LeaseDiagnostics? diagnostics,
  }) {
    final trace =
        diagnostics ??
        LeaseDiagnostics.current ??
        LeaseDiagnostics(role: LeaseRole.writer, intent: LeaseIntent.sync);
    var busySource = LeaseBusySource.leaseOpen;
    Database? db;
    try {
      db = _open(directory, key);
      if (db == null) return const Err(TransactionSyncStorageFailure());
      busySource = LeaseBusySource.leaseBegin;
      db.execute('BEGIN IMMEDIATE');
      final lock = WriterLock._(db, trace);
      trace.acquire();
      return Ok(lock);
    } on SqliteException catch (error) {
      if (db != null) _close(db);
      if (error.resultCode == 5) trace.busy(busySource);
      return Err(
        error.resultCode == 5
            ? const TransactionSyncBusyFailure()
            : const TransactionSyncStorageFailure(),
      );
    } on FileSystemException {
      if (db != null) _close(db);
      return const Err(TransactionSyncStorageFailure());
    }
  }

  /// Writer-only admission. Readers use [acquire] and never wait.
  static Future<Result<WriterLock, TransactionSyncFailure>> acquireWriter(
    String directory,
    WalletKey key, {
    required LeaseDiagnostics diagnostics,
  }) async {
    Database? db;
    var busySource = LeaseBusySource.leaseOpen;
    final waited = Stopwatch();
    try {
      db = _open(directory, key);
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
      if (db != null) _close(db);
    }
  }

  static Database? _open(String directory, WalletKey key) {
    Directory(directory).createSync(recursive: true);
    final db = sqlite3.open(path(directory, key));
    try {
      db.execute('PRAGMA busy_timeout = 0');
      // Refuse an unexpected journal configuration; no WAL lock semantics.
      if (db.select('PRAGMA journal_mode').single.values.single == 'delete') {
        // These lease-only connections never install Dart hooks or functions.
        // Detach native finalization before BEGIN can acquire the lease.
        _databaseFinalizer.attach(db, db.leak(), detach: db);
        return db;
      }
    } on Object {
      db.close();
      rethrow;
    }
    db.close();
    return null;
  }

  static void _closeHandle(Pointer<void> handle) =>
      sqlite3.fromPointer(handle).close();

  static void _close(Database db) {
    final handle = db.handle;
    _databaseFinalizer.detach(db);
    try {
      db.close();
    } finally {
      _closeHandle(handle);
    }
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
        _close(_db);
      } finally {
        _diagnostics.release(_held.elapsedMilliseconds);
      }
    }
  }
}
