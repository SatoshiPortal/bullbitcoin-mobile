import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/ark_wallet_failure.dart';

/// Separate rollback-journal connection. Held until native handles are disposed.
final class ArkWriterLock {
  final Database _db;
  bool _released = false;
  ArkWriterLock._(this._db);

  static Result<ArkWriterLock, ArkWalletFailure> acquire(
    String path, {
    bool existingOnly = false,
  }) {
    Database? db;
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
      db.execute('BEGIN IMMEDIATE');
      return Ok(ArkWriterLock._(db));
    } on SqliteException catch (error) {
      db?.close();
      return Err(
        error.resultCode == 5
            ? const ArkWriterBusyFailure()
            : const ArkStorageFailure(ArkFailureReason.storage),
      );
    } on FileSystemException {
      db?.close();
      return const Err(ArkStorageFailure(ArkFailureReason.storage));
    }
  }

  void release() {
    if (_released) return;
    try {
      _db.execute('ROLLBACK');
    } finally {
      _released = true;
      _db.close();
    }
  }
}
