import 'dart:ffi' show Pointer;

import 'package:sqlite3/sqlite3.dart';

/// Permanent lock-only sibling of the ledger. Never unlink or replace it.
/// No Dart hooks/functions are installed on this connection. Like Sync's writer
/// lock, a Dart finalizer keeps a killed holder's native lease until process exit.
final class ArkReminderGuard {
  static final _finalizer = Finalizer<Pointer<void>>(_closeHandle);

  final Database _db;
  bool _held = false;

  ArkReminderGuard._(this._db);

  static ArkReminderGuard open(String path, {required bool create}) {
    final db = sqlite3.open(
      path,
      mode: create ? OpenMode.readWriteCreate : OpenMode.readWrite,
    );
    ArkReminderGuard? guard;
    try {
      db.execute('PRAGMA busy_timeout = 0');
      if (db.select('PRAGMA journal_mode').single.values.single != 'delete') {
        throw const FormatException('Invalid reminder exclusion journal');
      }
      _finalizer.attach(db, db.leak(), detach: db);
      final opened = ArkReminderGuard._(db);
      guard = opened;
      opened.acquire();
      if (db
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .isNotEmpty) {
        throw const FormatException('Invalid reminder exclusion schema');
      }
      if (db.userVersion == 0 && create) {
        db.userVersion = 1;
        db.execute('COMMIT');
        opened._held = false;
        opened.acquire();
      }
      if (db.userVersion != 1 ||
          db.select('PRAGMA quick_check').single.values.single != 'ok') {
        throw const FormatException('Invalid reminder exclusion version');
      }
      return opened;
    } on Object {
      if (guard != null) {
        guard.close();
      } else {
        db.close();
      }
      rethrow;
    }
  }

  void acquire() {
    _db.execute('BEGIN IMMEDIATE');
    _held = true;
  }

  void release() {
    if (!_held) return;
    _db.execute('ROLLBACK');
    _held = false;
  }

  static void _closeHandle(Pointer<void> handle) =>
      sqlite3.fromPointer(handle).close();

  void close() {
    try {
      release();
    } finally {
      final handle = _db.handle;
      _finalizer.detach(_db);
      try {
        _db.close();
      } finally {
        _closeHandle(handle);
      }
    }
  }
}
