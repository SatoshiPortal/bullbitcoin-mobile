import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../transaction_sync.dart';

/// Only package:sqlite3 may open these files. Never unlink them, including on
/// wallet deletion. Acquire in the isolate awaiting the actual native work.
/// sqlite3 2.9.4 uses a Dart Finalizer: killing the holder leaks the connection
/// until process exit. Upgrading sqlite3 requires repeating the teardown tests.
final class WriterLock {
  final Database _db;
  bool _released = false;

  WriterLock._(this._db);

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
    WalletKey key,
  ) {
    Database? db;
    try {
      Directory(directory).createSync(recursive: true);
      db = sqlite3.open(path(directory, key));
      db.execute('PRAGMA busy_timeout = 0');
      // Refuse an unexpected journal configuration; no WAL lock semantics.
      if (db.select('PRAGMA journal_mode').single.values.single != 'delete') {
        db.dispose();
        return const Err(TransactionSyncStorageFailure());
      }
      db.execute('BEGIN IMMEDIATE');
      return Ok(WriterLock._(db));
    } on SqliteException catch (error) {
      db?.dispose();
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

  /// Call only after all native futures have settled. No timeout or cancellation
  /// wrapper may release a lease around an unfinished FRB operation.
  void release() {
    if (_released) return;
    try {
      _db.execute('ROLLBACK');
    } finally {
      _released = true;
      _db.dispose();
    }
  }
}
