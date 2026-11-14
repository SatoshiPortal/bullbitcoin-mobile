import 'dart:io';

import 'package:bull_sqlite/bull_sqlite.dart';
import 'package:bull_sqlite/src/sqlite_family.dart';
import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late String path;

  setUp(() => path = freshPath());
  tearDown(() => Directory(File(path).parent.path).deleteSync(recursive: true));

  T ok<T>(Result<T, SqliteStorageFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('unexpected $failure ${failure.logMessage}'),
  };

  SqliteStorageFailure err<T>(Result<T, SqliteStorageFailure> result) =>
      switch (result) {
        Ok() => fail('expected a failure'),
        Err(:final failure) => failure,
      };

  Database openKeyed(String path, DatabaseKey key) {
    final db = sqlite3.open(path, mode: OpenMode.readWrite);
    SqliteCipher.key(db, key);
    return db;
  }

  group('the build', () {
    test('loads SQLite3MultipleCiphers with the pinned cipher', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      expect(db.select('PRAGMA cipher;').single.values.single, 'chacha20');
    });
  });

  group('a new database', () {
    test('is created encrypted, never in clear', () {
      final key = keyOf(1);
      final db = sqlite3.open(path);
      SqliteCipher.configure(db, key, fullSync: true);
      db.execute('CREATE TABLE t (v TEXT);');
      db.execute("INSERT INTO t VALUES ('$canary');");
      db.close();

      expect(headerOf(path), isNot('SQLite format 3'));
      expect(canaryOnDisk(File(path).parent.path), isFalse);
      expect(
        ok(EncryptedSqlite.inspect(path)),
        SqliteFileState.possiblyEncrypted,
      );
    });

    test('opens only with its key', () {
      final db = sqlite3.open(path);
      SqliteCipher.configure(db, keyOf(1), fullSync: true);
      db.execute('CREATE TABLE t (v TEXT);');
      db.close();

      expect(
        EncryptedSqlite.probe(path, keyOf(1)),
        isA<Ok<void, SqliteStorageFailure>>(),
      );
      expect(
        err(EncryptedSqlite.probe(path, keyOf(2))),
        isA<SqliteKeyRejectedFailure>(),
      );

      final bare = sqlite3.open(path);
      addTearDown(bare.close);
      expect(
        () => bare.select('SELECT count(*) FROM sqlite_master;'),
        throwsA(isA<SqliteException>().having((e) => e.resultCode, 'code', 26)),
      );
    });

    test('a rejected key never appears in what is reported', () {
      final db = sqlite3.open(path);
      SqliteCipher.configure(db, keyOf(1), fullSync: true);
      db.execute('CREATE TABLE t (v TEXT);');
      db.close();

      final wrong = keyOf(9);
      final failure = err(EncryptedSqlite.probe(path, wrong));
      expect('$failure ${failure.logMessage}', isNot(contains(wrong.hex)));
      expect(
        () => openKeyed(path, wrong),
        throwsA(predicate((Object e) => !'$e'.contains(wrong.hex))),
      );
    });

    test('drift executor reads and writes through the key', () async {
      final key = keyOf(3);
      final executor = ok(EncryptedSqlite.open(path, key, fullSync: true));
      await executor.ensureOpen(_User());
      await executor.runCustom('CREATE TABLE t (v TEXT);');
      await executor.runCustom("INSERT INTO t VALUES ('$canary');");
      await executor.close();

      expect(headerOf(path), isNot('SQLite format 3'));
      final reopened = openKeyed(path, key);
      addTearDown(reopened.close);
      expect(reopened.select('SELECT v FROM t;').single['v'], canary);
    });
  });

  group('open refuses', () {
    test('a plaintext database', () {
      seedPlaintextWithUncheckpointedWal(path);
      expect(
        err(EncryptedSqlite.open(path, keyOf(1), fullSync: true)),
        isA<SqliteInconsistentFailure>(),
      );
    });

    test('a family with a pending retirement', () {
      File('$path.retire-pending').writeAsStringSync('delete');
      expect(
        err(EncryptedSqlite.open(path, keyOf(1), fullSync: true)),
        isA<SqliteInconsistentFailure>(),
      );
    });
  });

  group('userVersion', () {
    test('reads the encrypted user_version without migrating', () {
      final db = sqlite3.open(path);
      SqliteCipher.configure(db, keyOf(4), fullSync: true);
      db.execute('PRAGMA user_version = 16;');
      db.close();
      expect(ok(EncryptedSqlite.userVersion(path, keyOf(4))), 16);
      expect(
        err(EncryptedSqlite.userVersion(path, keyOf(5))),
        isA<SqliteKeyRejectedFailure>(),
      );
    });
  });

  test('userVersion syncs the directory first, and stops when it cannot', () {
    final missing =
        '${File(path).parent.path}/absent-${DateTime.now().microsecondsSinceEpoch}/x.sqlite';
    expect(
      err(EncryptedSqlite.userVersion(missing, keyOf(1))),
      isA<SqliteIoFailure>().having(
        (f) => f.logMessage,
        'logMessage',
        startsWith('filesystem error'),
      ),
    );
  });

  group('inspect', () {
    void touch(String suffix, {int bytes = 1}) =>
        File('$path$suffix').writeAsBytesSync(List.filled(bytes, 7));

    test('absent', () {
      expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.absent);
    });

    for (final suffix in ['-wal', '-shm']) {
      test(
        'an absent main file next to even an empty $suffix is inconsistent',
        () {
          touch(suffix, bytes: 0);
          expect(
            ok(EncryptedSqlite.inspect(path)),
            SqliteFileState.inconsistent,
          );
        },
      );
    }

    test('an empty main file next to an empty -shm is inconsistent', () {
      touch('', bytes: 0);
      touch('-shm', bytes: 0);
      expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.inconsistent);
    });

    test('quarantined copies next to an absent main file decide nothing', () {
      touch('.unreadable-1700000000000', bytes: 4096);
      touch('-wal.unreadable-1700000000000', bytes: 64);
      expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.absent);
    });

    for (final suffix in [
      '-wal',
      '-journal',
      '.encryption-tmp',
      '.encryption-tmp-journal',
    ]) {
      test('absent main file next to a non-empty $suffix is inconsistent', () {
        touch(suffix);
        expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.inconsistent);
      });

      test('empty main file next to a non-empty $suffix is inconsistent', () {
        touch('', bytes: 0);
        touch(suffix);
        expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.inconsistent);
      });
    }

    test('empty main file alone is empty', () {
      touch('', bytes: 0);
      expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.empty);
    });

    test('a main file shorter than a header is inconsistent', () {
      touch('', bytes: 15);
      expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.inconsistent);
    });

    test('a plaintext main file is plaintext, whatever is next to it', () {
      seedPlaintextWithUncheckpointedWal(path);
      touch('.encryption-tmp', bytes: 4096);
      expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.plaintext);
    });

    test('a pending retirement is inconsistent until resumed', () {
      seedPlaintextWithUncheckpointedWal(path);
      File('$path.retire-pending').writeAsStringSync('delete');
      expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.inconsistent);
    });

    test('inspection never opens or deletes anything', () {
      touch('', bytes: 0);
      touch('-wal');
      final before = Directory(File(path).parent.path).listSync().length;
      expect(ok(EncryptedSqlite.inspect(path)), SqliteFileState.inconsistent);
      expect(Directory(File(path).parent.path).listSync().length, before);
      expect(SqliteFamily(path).wal.lengthSync(), 1);
    });
  });

  group('barrier', () {
    test('syncs an existing directory', () {
      expect(
        EncryptedSqlite.barrier(path),
        isA<Ok<void, SqliteStorageFailure>>(),
      );
    });

    test('fails for a directory that does not exist', () {
      expect(
        err(
          EncryptedSqlite.barrier(
            '/nonexistent-${DateTime.now().microsecondsSinceEpoch}/x.sqlite',
          ),
        ),
        isA<SqliteIoFailure>(),
      );
    });
  });
}

class _User implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
