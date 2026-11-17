import 'dart:ffi' show Pointer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sqlite3/sqlite3.dart';

/// Wallet-owned admission. Only foreground construction may initialize parents.
/// Lock files are permanent: never unlink them, even after seed deletion.
final class SqliteParentCustodyAdmission implements ParentCustodyAdmissionPort {
  final Future<String> Function() _directory;
  final bool mayCreate;
  final Duration waitLimit;

  SqliteParentCustodyAdmission({
    required this._directory,
    required this.mayCreate,
    this.waitLimit = const Duration(seconds: 1),
  }) {
    if (waitLimit.isNegative) throw ArgumentError.value(waitLimit, 'waitLimit');
  }

  @override
  Future<Result<T, ParentCustodyFailure>> runExclusive<T>(
    Fingerprint parent,
    Future<Result<T, ParentCustodyFailure>> Function(ParentCustodyLease) action,
  ) async {
    final String directory;
    try {
      directory = await _directory();
    } on Exception {
      return const Err(ParentCustodyStorageFailure());
    }
    final waited = Stopwatch()..start();
    while (true) {
      final result = _acquire(directory, parent);
      switch (result) {
        case Ok(:final value):
          try {
            return await action(value);
          } finally {
            value.close();
          }
        case Err(failure: ParentCustodyBusyFailure()):
          final remaining = waitLimit - waited.elapsed;
          if (remaining <= Duration.zero) {
            return const Err(ParentCustodyBusyFailure());
          }
          const delay = Duration(milliseconds: 25);
          await Future<void>.delayed(delay < remaining ? delay : remaining);
        case Err(:final failure):
          return Err(failure);
      }
    }
  }

  Result<_Lease, ParentCustodyFailure> _acquire(
    String directory,
    Fingerprint parent,
  ) {
    _Exclusion? initializing;
    _Exclusion? exclusion;
    Database? state;
    try {
      final root = Directory(p.join(directory, 'parent_custody'));
      if (mayCreate) root.createSync(recursive: true);
      // Serialize first-create evidence before any parent lock can be created.
      // The initializer has no user state; it too is never replaced/unlinked.
      initializing = _Exclusion.acquire(
        p.join(root.path, 'initialize.sqlite'),
        create: mayCreate,
      );
      final lockPath = p.join(root.path, '${parent.hex}.lock.sqlite');
      final statePath = p.join(root.path, '${parent.hex}.state.sqlite');
      final fresh = !File(lockPath).existsSync();
      if (fresh && !mayCreate) {
        return const Err(ParentCustodyMetadataFailure());
      }
      final exists = File(statePath).existsSync();
      if (!exists && !(fresh && mayCreate)) {
        return const Err(ParentCustodyMetadataFailure());
      }
      if (!exists) _initializeState(statePath);
      // No permanent parent lock exists before committed initial state. A
      // crash before rename leaves only an unused temp; after rename the next
      // foreground opener can finish creating the permanent exclusion file.
      exclusion = _Exclusion.acquire(lockPath, create: fresh && mayCreate);
      initializing.close();
      initializing = null;
      state = sqlite3.open(statePath, mode: OpenMode.readWrite);
      state.execute('PRAGMA busy_timeout = 0');
      state.execute('PRAGMA synchronous = FULL');
      if (state.userVersion != 1) {
        return const Err(ParentCustodyMetadataFailure());
      }
      final lease = _Lease(exclusion, state);
      if (lease.readState() case Err(:final failure)) return Err(failure);
      exclusion = null;
      state = null;
      return Ok(lease);
    } on SqliteException catch (error) {
      return Err(
        error.resultCode == 5
            ? const ParentCustodyBusyFailure()
            : (error.resultCode == 1 ||
                  error.resultCode == 11 ||
                  error.resultCode == 26)
            ? const ParentCustodyMetadataFailure()
            : const ParentCustodyStorageFailure(),
      );
    } on FileSystemException {
      return const Err(ParentCustodyStorageFailure());
    } finally {
      state?.close();
      exclusion?.close();
      initializing?.close();
    }
  }

  static void _initializeState(String path) {
    final temporary = File(path).parent
        .createTempSync('.custody-initializing-');
    final file = File(p.join(temporary.path, 'state.sqlite'));
    final db = sqlite3.open(file.path);
    try {
      db.execute('PRAGMA synchronous = FULL');
      db.execute('BEGIN IMMEDIATE');
      db.execute(
        'CREATE TABLE custody (id INTEGER PRIMARY KEY CHECK '
        '(id = 1), state TEXT NOT NULL CHECK '
        "(state IN ('ready', 'deleting', 'deleted')))",
      );
      db.execute("INSERT INTO custody VALUES (1, 'ready')");
      db.userVersion = 1;
      db.execute('COMMIT');
    } finally {
      db.close();
    }
    file.renameSync(path);
    temporary.deleteSync();
  }
}

final class _Lease implements ParentCustodyLease {
  final _Exclusion _exclusion;
  final Database _state;
  bool _active = true;

  _Lease(this._exclusion, this._state);

  @override
  Result<ParentCustodyState, ParentCustodyFailure> readState() {
    if (!_active) return const Err(ParentCustodyStateFailure());
    try {
      final rows = _state.select('SELECT id, state FROM custody');
      if (rows.length != 1 || rows.single['id'] != 1) {
        return const Err(ParentCustodyMetadataFailure());
      }
      return switch (rows.single['state']) {
        'ready' => const Ok(ParentCustodyState.ready),
        'deleting' => const Ok(ParentCustodyState.deleting),
        'deleted' => const Ok(ParentCustodyState.deleted),
        _ => const Err(ParentCustodyMetadataFailure()),
      };
    } on SqliteException catch (error) {
      return Err(
        (error.resultCode == 1 ||
                error.resultCode == 11 ||
                error.resultCode == 26)
            ? const ParentCustodyMetadataFailure()
            : const ParentCustodyStorageFailure(),
      );
    }
  }

  @override
  Result<void, ParentCustodyFailure> markDeleting() =>
      _transition(ParentCustodyState.ready, ParentCustodyState.deleting);

  @override
  Result<void, ParentCustodyFailure> markDeleted() =>
      _transition(ParentCustodyState.deleting, ParentCustodyState.deleted);

  @override
  Result<void, ParentCustodyFailure> reconcilePresent() {
    switch (readState()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return _transition(value, ParentCustodyState.ready);
    }
  }

  Result<void, ParentCustodyFailure> _transition(
    ParentCustodyState expected,
    ParentCustodyState next,
  ) {
    switch (readState()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when value != expected:
        return const Err(ParentCustodyStateFailure());
      case Ok():
    }
    try {
      _state.execute(
        'UPDATE custody SET state = ? WHERE id = 1 AND state = ?',
        [next.name, expected.name],
      );
      return _state.updatedRows == 1
          ? const Ok(null)
          : const Err(ParentCustodyStateFailure());
    } on SqliteException {
      return const Err(ParentCustodyStorageFailure());
    }
  }

  void close() {
    _active = false;
    try {
      _state.close();
    } finally {
      _exclusion.close();
    }
  }
}

/// Match sync's isolate-death rule: leaking detaches sqlite3's native finalizer.
/// A killed isolate therefore keeps exclusion until process exit, while normal
/// completion closes explicitly. No Dart callbacks are installed on this DB.
final class _Exclusion {
  static final _finalizer = Finalizer<Pointer<void>>(_closeHandle);
  final Database _db;

  _Exclusion(this._db);

  static _Exclusion acquire(String path, {required bool create}) {
    final db = sqlite3.open(
      path,
      mode: create ? OpenMode.readWriteCreate : OpenMode.readWrite,
    );
    try {
      db.execute('PRAGMA busy_timeout = 0');
      if (db.select('PRAGMA journal_mode').single.values.single != 'delete') {
        throw const FileSystemException('unexpected custody lock journal');
      }
      _finalizer.attach(db, db.leak(), detach: db);
    } on Object {
      db.close();
      rethrow;
    }
    try {
      db.execute('BEGIN IMMEDIATE');
      return _Exclusion(db);
    } on Object {
      _close(db);
      rethrow;
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

  void close() {
    try {
      _db.execute('ROLLBACK');
    } finally {
      _close(_db);
    }
  }
}
