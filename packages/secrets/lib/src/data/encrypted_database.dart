import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/database_key_repository.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:sqlite3/sqlite3.dart';

Future<Result<QueryExecutor, DatabaseOpenFailure>> openEncryptedDatabase(
  DatabaseKeyRepository keys, {
  required String module,
  required String name,
  required File file,
  required int? existingSchemaVersion,
}) async {
  const cipher = 'chacha20';
  final background = existingSchemaVersion != null;
  Database? database;
  try {
    final path = file.path;
    final length = _lengthIfPresent(file);
    final exists = length != null;
    final pending = _lengthIfPresent(File('$path.retire-pending')) != null;
    final hasSidecar = [
      '-wal',
      '-shm',
      '-journal',
    ].any((suffix) => _lengthIfPresent(File('$path$suffix')) != null);
    if (pending || (hasSidecar && (length == null || length == 0))) {
      return const Err(
        DatabaseFileUnavailable(DatabaseFileProblem.inconsistent),
      );
    }
    if (background && !exists) return const Err(DatabaseNotReady());

    final key = exists
        ? await keys.existing(module: module, name: name)
        : await keys.forModule(module: module, name: name);
    final DatabaseKey selected;
    switch (key) {
      case Err(:final failure):
        return Err(_keyFailure(failure));
      case Ok(:final value):
        selected = value;
    }
    if (!exists) {
      // Do not write encrypted data until the key is readable from the store.
      final persisted = await keys.existing(module: module, name: name);
      switch (persisted) {
        case Err(failure: SecretNotFoundFailure()):
          return const Err(
            DatabaseKeyUnavailable(DatabaseKeyProblem.unavailable),
          );
        case Err(:final failure):
          return Err(_keyFailure(failure));
        case Ok(:final value) when value.hex != selected.hex:
          return const Err(
            DatabaseKeyUnavailable(DatabaseKeyProblem.unavailable),
          );
        case Ok():
          file.parent.createSync(recursive: true);
      }
    }

    database = sqlite3.open(
      path,
      mode: exists ? OpenMode.readWrite : OpenMode.readWriteCreate,
    );
    database.execute('PRAGMA busy_timeout = 2000');
    if (database.select('PRAGMA cipher').isEmpty) {
      return const Err(DatabaseCipherUnavailable());
    }
    database.execute("PRAGMA cipher = '$cipher'");
    if (database.select('PRAGMA cipher').single.values.single != cipher) {
      return const Err(DatabaseCipherUnavailable());
    }
    database.execute('PRAGMA key = "${selected.pragma}"');
    // PRAGMA key itself succeeds even for a wrong key.
    database.select('SELECT count(*) FROM sqlite_master');
    if (background) {
      final version = database.userVersion;
      // An older file has not been migrated yet by the foreground app: wait.
      // A newer one was written by a schema this build does not know.
      if (version > existingSchemaVersion) {
        return const Err(
          DatabaseFileUnavailable(DatabaseFileProblem.schemaMismatch),
        );
      }
      if (version != existingSchemaVersion) {
        return const Err(DatabaseNotReady());
      }
    } else {
      final mode = database.select('PRAGMA journal_mode = WAL');
      if (mode.single.values.single != 'wal') {
        return const Err(
          DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
        );
      }
    }
    database.execute('PRAGMA synchronous = FULL');

    final executor = NativeDatabase.opened(
      database,
      enableMigrations: !background,
      closeUnderlyingOnClose: false,
    ).interceptWith(_CloseNativeConnection(database), sticky: false);
    database = null; // Ownership transferred to Drift.
    return Ok(executor);
  } on SqliteException catch (error) {
    // The causing SQL statement can include the key. Never forward the error.
    return Err(DatabaseFileUnavailable(databaseFileProblemOf(error)));
  } on FileSystemException {
    return const Err(DatabaseFileUnavailable(DatabaseFileProblem.inaccessible));
  } finally {
    database?.close();
  }
}

/// Classifies an engine error without reading its message, which can carry the
/// statement and therefore the key.
DatabaseFileProblem databaseFileProblemOf(SqliteException error) =>
    switch (error.resultCode) {
      SqlError.SQLITE_NOTADB ||
      SqlError.SQLITE_CORRUPT => DatabaseFileProblem.unreadable,
      SqlError.SQLITE_BUSY ||
      SqlError.SQLITE_LOCKED => DatabaseFileProblem.contended,
      _ => DatabaseFileProblem.inaccessible,
    };

// Only a missing path can permit provisioning. An inaccessible path must
// leave any existing key untouched.
int? _lengthIfPresent(File file) {
  try {
    return file.lengthSync();
  } on PathNotFoundException {
    return null;
  }
}

DatabaseKeyUnavailable _keyFailure(SecretFailure failure) =>
    DatabaseKeyUnavailable(switch (failure) {
      KeystoreLockedFailure() => DatabaseKeyProblem.locked,
      SecretNotFoundFailure() => DatabaseKeyProblem.missing,
      DatabaseKeyCorruptFailure() => DatabaseKeyProblem.corrupt,
      _ => DatabaseKeyProblem.unavailable,
    });

// Drift's close is a no-op before its first query, but the keyed handle is
// already open. Own its close independently of whether a query ran.
final class _CloseNativeConnection extends QueryInterceptor {
  final Database _database;
  Future<void>? _closing;

  _CloseNativeConnection(this._database);

  @override
  Future<void> close(QueryExecutor inner) => _closing ??= _close(inner);

  Future<void> _close(QueryExecutor inner) async {
    try {
      await inner.close();
    } finally {
      _database.close();
    }
  }
}
