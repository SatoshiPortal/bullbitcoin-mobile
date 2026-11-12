import 'dart:io';

import 'package:bull_sqlite/src/directory_barrier.dart';
import 'package:bull_sqlite/src/exceptions.dart';
import 'package:bull_sqlite/src/retire.dart' as retirement;
import 'package:bull_sqlite/src/retire.dart' show Retirement;
import 'package:bull_sqlite/src/sqlite_cipher.dart';
import 'package:bull_sqlite/src/sqlite_family.dart';
import 'package:bull_sqlite/src/sqlite_storage_failure.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

/// Local SQLite databases encrypted at rest: the operations their owners compose.
///
/// Every operation takes the path of the main database file and works on its whole family (`-wal`, `-shm`, `-journal`, the encryption candidate, the retirement marker). None decides which key to use or whether to create one: that policy belongs to the owner, which alone knows whether a missing key may be created (see `features/local_data`).
///
/// ⚠️ Only databases opened through this package are encrypted. The stores that wallet libraries keep next to them (BDK, LWK, Silent Payments) are written by native code that this package does not reach, and remain as their library writes them; see the README.
abstract final class EncryptedSqlite {
  /// Classifies the family from file lengths and headers, without opening it.
  @useResult
  static Result<SqliteFileState, SqliteStorageFailure> inspect(String path) =>
      _guard(() => SqliteFamily(path).inspect());

  /// Opens the possibly encrypted database at [path] with [key], lets SQLite recover a hot journal or WAL, and checks its integrity. Removes an encryption candidate left next to it only after that succeeds.
  ///
  /// Syncs the directory first, so a database published by a rename whose sync failed is made durable before anything reads it.
  @useResult
  static Result<void, SqliteStorageFailure> probe(
    String path,
    DatabaseKey key,
  ) => _guard(() {
    final family = SqliteFamily(path);
    DirectoryBarrier.sync(family.directory);
    final database = _run(() => sqlite3.open(path, mode: OpenMode.readWrite));
    try {
      SqliteCipher.key(database, key);
      final check = _run(() => database.select('PRAGMA quick_check;'));
      if (check.length != 1 || check.first.values.first != 'ok') {
        throw const SqliteFailedException(sqliteCorrupt);
      }
    } finally {
      database.close();
    }
    for (final stale in [family.candidate, family.candidateJournal]) {
      if (stale.existsSync()) stale.deleteSync();
    }
  });

  /// The `user_version` of the encrypted database at [path], read with [key] and without drift: opening through drift would run the migrations this read exists to gate. Never creates the file.
  @useResult
  static Result<int, SqliteStorageFailure> userVersion(
    String path,
    DatabaseKey key,
  ) => _guard(() {
    final database = _run(() => sqlite3.open(path, mode: OpenMode.readWrite));
    try {
      _run(() => database.execute('PRAGMA busy_timeout = 2000;'));
      SqliteCipher.key(database, key);
      return _run(() => database.userVersion);
    } finally {
      database.close();
    }
  });

  /// Makes the directory holding [path] durable. Every open does it; exposed for owners that open through another executor (the foreground main database, through `drift_flutter`).
  @useResult
  static Result<void, SqliteStorageFailure> barrier(String path) =>
      _guard(() => DirectoryBarrier.sync(SqliteFamily(path).directory));

  /// A drift executor on the database at [path], keyed with [key] before any other statement on every connection it opens, in a background isolate.
  ///
  /// Refuses a plaintext database (it must be encrypted first), an inconsistent family and a pending retirement; syncs the directory before returning. An absent or empty database is created encrypted: the key is set before the first page is written.
  @useResult
  static Result<QueryExecutor, SqliteStorageFailure> open(
    String path,
    DatabaseKey key, {
    required bool fullSync,
  }) => _guard(() {
    final family = SqliteFamily(path);
    switch (family.inspect()) {
      case SqliteFileState.plaintext:
        throw const InconsistentFamilyException('database is not encrypted');
      case SqliteFileState.inconsistent:
        throw const InconsistentFamilyException('family needs a decision');
      case SqliteFileState.absent ||
          SqliteFileState.empty ||
          SqliteFileState.possiblyEncrypted:
        break;
    }
    DirectoryBarrier.sync(family.directory);
    return NativeDatabase.createInBackground(
      File(path),
      setup: (database) =>
          SqliteCipher.configure(database, key, fullSync: fullSync),
    );
  });

  /// Deletes or quarantines the whole family, resumably. See [retirement.retire].
  @useResult
  static Result<void, SqliteStorageFailure> retire(
    String path,
    Retirement how,
  ) => _guard(() => retirement.retire(SqliteFamily(path), how));

  /// Finishes a retirement interrupted earlier; `true` if there was one.
  @useResult
  static Result<bool, SqliteStorageFailure> resumeRetirement(String path) =>
      _guard(() => retirement.resumeRetirement(SqliteFamily(path)));

  /// The failure for an error raised while keying or using a connection — for owners whose executor runs [SqliteCipher.configure] and sees its errors surface later, from drift.
  static SqliteStorageFailure failureOf(Object error) => switch (error) {
    CipherUnavailableException() => const SqliteCipherUnavailableFailure(),
    KeyRejectedException() => const SqliteKeyRejectedFailure(),
    InconsistentFamilyException(:final reason) => SqliteInconsistentFailure(
      reason,
    ),
    MigrationAbortedException(:final reason) => SqliteIoFailure(reason),
    SqliteFailedException(:final resultCode) => switch (resultCode) {
      sqliteBusy || sqliteLocked => const SqliteBusyFailure(),
      sqliteCorrupt => const SqliteCorruptFailure(),
      sqliteNotADatabase => const SqliteKeyRejectedFailure(),
      _ => SqliteIoFailure('sqlite error $resultCode'),
    },
    // Reduced to its code: the statement may carry the key.
    SqliteException(:final extendedResultCode) => failureOf(
      SqliteFailedException(extendedResultCode),
    ),
    FileSystemException(:final osError) => SqliteIoFailure(
      'filesystem error ${osError?.errorCode}',
    ),
    _ => SqliteIoFailure(error.runtimeType.toString()),
  };

  static Result<T, SqliteStorageFailure> _guard<T>(T Function() body) {
    try {
      return Ok(body());
    } on Exception catch (error) {
      return Err(failureOf(error));
    }
  }

  static T _run<T>(T Function() body) {
    try {
      return body();
    } on SqliteException catch (e) {
      throw SqliteFailedException.from(e);
    }
  }
}
