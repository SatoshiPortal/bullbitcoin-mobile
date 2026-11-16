import 'dart:io';
import 'dart:ffi' show Pointer;

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/ark_wallet_failure.dart';

/// Separate rollback-journal connection. Held until native handles are disposed.
/// Detaching sqlite3's native finalizer and attaching a Dart finalizer keeps a
/// killed isolate's lease open until process exit: Rust may still be running.
/// These lock-only connections never install Dart callbacks or SQL functions.
final class ArkWriterLock {
  static final _finalizer = Finalizer<Pointer<void>>(_closeHandle);
  final Database _db;
  bool _released = false;
  ArkWriterLock._(this._db);

  static Result<ArkWriterLock, ArkWalletFailure> acquire(
    String path, {
    bool existingOnly = false,
  }) {
    Database? db;
    var pinned = false;
    try {
      if (existingOnly && !File(path).existsSync()) {
        return const Err(
          ArkUnavailableFailure(ArkFailureReason.accountMissing),
        );
      }
      if (!existingOnly) File(path).parent.createSync(recursive: true);
      db = sqlite3.open(
        path,
        mode: existingOnly ? OpenMode.readWrite : OpenMode.readWriteCreate,
      );
      db.execute('PRAGMA busy_timeout = 0');
      if (db.select('PRAGMA journal_mode').single.values.single != 'delete') {
        db.close();
        return const Err(ArkStorageFailure(ArkFailureReason.storage));
      }
      _finalizer.attach(db, db.leak(), detach: db);
      pinned = true;
      db.execute('BEGIN IMMEDIATE');
      return Ok(ArkWriterLock._(db));
    } on SqliteException catch (error) {
      if (db case final connection?) {
        if (pinned) {
          _close(connection);
        } else {
          connection.close();
        }
      }
      return Err(
        error.resultCode == 5
            ? const ArkWriterBusyFailure()
            : const ArkStorageFailure(ArkFailureReason.storage),
      );
    } on FileSystemException {
      if (db case final connection?) {
        if (pinned) {
          _close(connection);
        } else {
          connection.close();
        }
      }
      return const Err(ArkStorageFailure(ArkFailureReason.storage));
    }
  }

  static void _closeHandle(Pointer<void> handle) =>
      sqlite3.fromPointer(handle).close();

  static void _close(Database db) {
    final handle = db.handle;
    _finalizer.detach(db);
    try {
      db.close();
    } finally {
      _closeHandle(handle);
    }
  }

  void release() {
    if (_released) return;
    try {
      _db.execute('ROLLBACK');
    } finally {
      _released = true;
      _close(_db);
    }
  }
}
