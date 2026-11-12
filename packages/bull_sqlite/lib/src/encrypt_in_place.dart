import 'dart:io';

import 'package:bull_sqlite/src/directory_barrier.dart';
import 'package:bull_sqlite/src/exceptions.dart';
import 'package:bull_sqlite/src/sqlite_cipher.dart';
import 'package:bull_sqlite/src/sqlite_family.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show DatabaseKey;
import 'package:sqlite3/sqlite3.dart';

/// The points of [encryptInPlace], in order. Tests stop the process at each one.
enum EncryptionStep {
  sourceSettled,
  staleCandidateRemoved,
  copied,
  rekeyed,
  verified,
  flushed,
  replaced,
  published,
}

/// Encrypts the plaintext database of [family] with [key], by one atomic replace.
///
/// 1. The plaintext source is opened, checked (`quick_check`) and moved to `journal_mode=DELETE` with `synchronous=FULL`: SQLite replays and checkpoints any WAL or hot journal, syncs the file, and leaves neither sidecar. Only then is a candidate left by an earlier attempt removed: a derived copy of a source that is now proven intact.
/// 2. `VACUUM INTO` writes a consistent plaintext copy (the candidate), which SQLite3MultipleCiphers then encrypts with `PRAGMA rekey` (it requires a non-WAL journal mode for that).
/// 3. The candidate is reopened with the key and compared with the source: integrity, `user_version`, schema, and every row of every table.
/// 4. The candidate is flushed to disk, renamed over the source, and the directory is synced. The rename is the commit point: before it the plaintext database is untouched and the candidate is only a copy; after it the encrypted database is the database.
///
/// Any failure before the rename removes the candidate (best effort) and leaves the plaintext database as it was. A failure after it leaves an encrypted database whose publication may not be durable yet: every open syncs the directory first (`EncryptedSqlite.open`), so nothing writes to it before publication is durable.
///
/// Synchronous on purpose: run it off the UI isolate (`EncryptedSqlite.encrypt` does). Only the foreground app may call it; a concurrent connection makes step 1 fail rather than wait.
void encryptInPlace(
  SqliteFamily family,
  DatabaseKey key, {
  @visibleForTesting void Function(EncryptionStep step)? onStep,
}) {
  if (family.inspect() != SqliteFileState.plaintext) {
    throw const MigrationAbortedException('source is not a plaintext database');
  }
  void reached(EncryptionStep step) => onStep?.call(step);

  var replaced = false;
  try {
    final userVersion = _settleSource(family);
    reached(EncryptionStep.sourceSettled);

    for (final stale in [family.candidate, family.candidateJournal]) {
      if (stale.existsSync()) stale.deleteSync();
    }
    reached(EncryptionStep.staleCandidateRemoved);

    _copy(family);
    reached(EncryptionStep.copied);

    _rekeyCandidate(family, key);
    reached(EncryptionStep.rekeyed);

    _verifyCandidate(family, key, userVersion);
    reached(EncryptionStep.verified);

    final handle = family.candidate.openSync(mode: FileMode.append);
    try {
      handle.flushSync();
    } finally {
      handle.closeSync();
    }
    reached(EncryptionStep.flushed);

    family.candidate.renameSync(family.path);
    replaced = true;
    reached(EncryptionStep.replaced);

    DirectoryBarrier.sync(family.directory);
    reached(EncryptionStep.published);
  } catch (_) {
    if (!replaced) _discardCandidate(family);
    rethrow;
  }
}

/// Opens the plaintext source, lets SQLite recover it, checks it and leaves it in rollback-journal mode. Returns its `user_version`.
int _settleSource(SqliteFamily family) {
  final source = _open(family.path);
  try {
    _run(() {
      source.execute('PRAGMA busy_timeout = 2000;');
      source.execute('PRAGMA synchronous = FULL;');
    });
    _requireIntact(source, 'source failed its integrity check');
    final mode = _run(() => source.select('PRAGMA journal_mode = DELETE;'));
    // SQLite answers with the mode in force: still `wal` when another connection holds the database.
    if (mode.isEmpty ||
        '${mode.first.values.first}'.toLowerCase() != 'delete') {
      throw const MigrationAbortedException(
        'source could not leave WAL mode; another connection holds it',
      );
    }
    final version = _run(() => source.userVersion);
    return version;
  } finally {
    source.close();
  }
}

void _copy(SqliteFamily family) {
  if (family.wal.existsSync() && family.wal.lengthSync() > 0) {
    throw const MigrationAbortedException('source still has a WAL');
  }
  if (family.journal.existsSync() && family.journal.lengthSync() > 0) {
    throw const MigrationAbortedException('source still has a hot journal');
  }
  final source = _open(family.path);
  try {
    final target = family.candidate.path.replaceAll("'", "''");
    _run(() => source.execute("VACUUM INTO '$target';"));
  } finally {
    source.close();
  }
}

void _rekeyCandidate(SqliteFamily family, DatabaseKey key) {
  final candidate = _open(family.candidate.path);
  try {
    final mode = _run(() => candidate.select('PRAGMA journal_mode;'));
    if (mode.isEmpty ||
        '${mode.first.values.first}'.toLowerCase() != 'delete') {
      throw const MigrationAbortedException('copy is not in rollback mode');
    }
    SqliteCipher.rekey(candidate, key);
  } finally {
    candidate.close();
  }
}

void _verifyCandidate(SqliteFamily family, DatabaseKey key, int userVersion) {
  final source = _open(family.path, mode: OpenMode.readOnly);
  try {
    final candidate = _open(family.candidate.path);
    try {
      SqliteCipher.key(candidate, key);
      _requireIntact(candidate, 'copy failed its integrity check');
      if (_run(() => candidate.userVersion) != userVersion) {
        throw const MigrationAbortedException('copy changed user_version');
      }
      const schema =
          'SELECT type, name, tbl_name, sql FROM sqlite_master '
          'ORDER BY type, name;';
      if (!_sameRows(source, candidate, schema)) {
        throw const MigrationAbortedException('copy changed the schema');
      }
      final tables = _run(
        () => source.select(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name;",
        ),
      );
      for (final row in tables) {
        final table = '"${'${row['name']}'.replaceAll('"', '""')}"';
        final columns =
            _run(
                  () => source.select(
                    'SELECT count(*) AS n FROM pragma_table_info(?);',
                    [row['name']],
                  ),
                ).first['n']
                as int;
        final orderBy = [for (var i = 1; i <= columns; i++) '$i'].join(', ');
        if (!_sameRows(
          source,
          candidate,
          'SELECT * FROM $table ORDER BY $orderBy;',
        )) {
          throw const MigrationAbortedException('copy changed a table');
        }
      }
    } finally {
      candidate.close();
    }
  } finally {
    source.close();
  }
}

/// Compares two result sets row by row, without holding either in memory.
bool _sameRows(Database a, Database b, String sql) {
  final left = _run(() => a.prepare(sql));
  final right = _run(() => b.prepare(sql));
  try {
    final l = _run(() => left.selectCursor());
    final r = _run(() => right.selectCursor());
    while (true) {
      final hasLeft = _run(l.moveNext);
      final hasRight = _run(r.moveNext);
      if (hasLeft != hasRight) return false;
      if (!hasLeft) return true;
      if (!_sameValues(l.current.values, r.current.values)) return false;
    }
  } finally {
    left.close();
    right.close();
  }
}

bool _sameValues(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x is List<int> && y is List<int>) {
      if (x.length != y.length) return false;
      for (var j = 0; j < x.length; j++) {
        if (x[j] != y[j]) return false;
      }
    } else if (x != y) {
      return false;
    }
  }
  return true;
}

void _requireIntact(Database database, String reason) {
  final result = _run(() => database.select('PRAGMA quick_check;'));
  if (result.length != 1 || result.first.values.first != 'ok') {
    throw MigrationAbortedException(reason);
  }
}

void _discardCandidate(SqliteFamily family) {
  for (final file in [family.candidate, family.candidateJournal]) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Best effort: a candidate is never the only copy, and the next attempt removes it after settling the source.
    }
  }
}

Database _open(String path, {OpenMode mode = OpenMode.readWrite}) =>
    _run(() => sqlite3.open(path, mode: mode));

T _run<T>(T Function() body) {
  try {
    return body();
  } on SqliteException catch (e) {
    throw SqliteFailedException.from(e);
  }
}
