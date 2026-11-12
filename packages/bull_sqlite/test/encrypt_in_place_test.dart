import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bull_sqlite/bull_sqlite.dart';
import 'package:bull_sqlite/src/encrypt_in_place.dart';
import 'package:bull_sqlite/src/retire.dart';
import 'package:bull_sqlite/src/sqlite_family.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late String path;
  late int rows;

  setUp(() {
    path = freshPath();
    rows = seedPlaintextWithUncheckpointedWal(path);
  });
  tearDown(() => Directory(File(path).parent.path).deleteSync(recursive: true));

  String directory() => File(path).parent.path;

  /// The database as the app left it: every row (including those only in the WAL), the blob, the WITHOUT ROWID table, the index, the view, user_version.
  void expectIntact(DatabaseKey key) {
    final db = sqlite3.open(path, mode: OpenMode.readWrite);
    addTearDown(db.close);
    SqliteCipher.key(db, key);
    expect(db.select('PRAGMA quick_check;').single.values.single, 'ok');
    expect(db.userVersion, 16);
    expect(db.select('SELECT count(*) AS n FROM labels;').single['n'], rows);
    expect(
      db.select('SELECT label FROM labels WHERE id = 251;').single['label'],
      canary,
    );
    expect(
      db.select('SELECT payload FROM labels WHERE id = 300;').single['payload'],
      Uint8List.fromList([299 % 256, 1, 2, 3]),
    );
    expect(
      db.select("SELECT v FROM kv WHERE k = 'secret';").single['v'],
      canary,
    );
    final names = db
        .select('SELECT name FROM sqlite_master ORDER BY name;')
        .map((r) => r['name'])
        .toList();
    expect(names, containsAll(['labels', 'labels_label', 'labelled', 'kv']));
  }

  void expectNoLeftovers() {
    final family = SqliteFamily(path);
    for (final file in [
      family.candidate,
      family.candidateJournal,
      family.journal,
    ]) {
      expect(file.existsSync(), isFalse, reason: file.path);
    }
    expect(canaryOnDisk(directory()), isFalse);
  }

  Future<void> encrypt(DatabaseKey key) async {
    expect(
      await EncryptedSqlite.encrypt(path, key),
      isA<Ok<void, SqliteStorageFailure>>(),
    );
  }

  test(
    'encrypts every row, the WAL included, and leaves nothing in clear',
    () async {
      final key = keyOf(10);
      await encrypt(key);

      expect(headerOf(path), isNot('SQLite format 3'));
      expect(SqliteFamily(path).inspect(), SqliteFileState.possiblyEncrypted);
      expectIntact(key);
      expectNoLeftovers();
    },
  );

  test('refuses anything that is not a plaintext database', () async {
    final key = keyOf(10);
    await encrypt(key);
    final again = await EncryptedSqlite.encrypt(path, key);
    expect((again as Err).failure, isA<SqliteIoFailure>());
    expectIntact(key);
  });

  test(
    'a connection holding the database stops it before anything changes',
    () async {
      final holder = sqlite3.open(path, mode: OpenMode.readWrite);
      addTearDown(holder.close);
      holder.execute('BEGIN;');
      holder.select('SELECT count(*) FROM labels;');

      final result = await EncryptedSqlite.encrypt(path, keyOf(10));
      expect(result, isA<Err<void, SqliteStorageFailure>>());
      holder.execute('COMMIT;');
      expect(SqliteFamily(path).inspect(), SqliteFileState.plaintext);
      expect(SqliteFamily(path).candidate.existsSync(), isFalse);
    },
  );

  test(
    'a corrupt source is reported as corrupt, and a candidate next to it is kept',
    () async {
      corruptPlaintext(path);
      final candidate = SqliteFamily(path).candidate
        ..writeAsStringSync('an earlier copy');

      final result = await EncryptedSqlite.encrypt(path, keyOf(10));

      expect(
        result,
        isA<Err<void, SqliteStorageFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<SqliteCorruptFailure>(),
        ),
      );
      expect(candidate.readAsStringSync(), 'an earlier copy');
      expect(headerOf(path), 'SQLite format 3');
    },
  );

  group('an error at a step', () {
    for (final step in EncryptionStep.values.where(
      (s) => s.index < EncryptionStep.replaced.index,
    )) {
      test(
        '${step.name} leaves the plaintext database untouched, and a retry encrypts it',
        () async {
          expect(
            () => encryptInPlace(
              SqliteFamily(path),
              keyOf(10),
              onStep: (s) {
                if (s == step) throw const FileSystemException('injected');
              },
            ),
            throwsA(isA<FileSystemException>()),
          );
          expect(SqliteFamily(path).inspect(), SqliteFileState.plaintext);
          expect(SqliteFamily(path).candidate.existsSync(), isFalse);
          final plain = sqlite3.open(path, mode: OpenMode.readOnly);
          expect(
            plain.select('SELECT count(*) AS n FROM labels;').single['n'],
            rows,
          );
          plain.close();

          await encrypt(keyOf(10));
          expectIntact(keyOf(10));
          expectNoLeftovers();
        },
      );
    }

    test('after the replace leaves the encrypted database, which opens', () {
      expect(
        () => encryptInPlace(
          SqliteFamily(path),
          keyOf(10),
          onStep: (s) {
            if (s == EncryptionStep.replaced) {
              throw const FileSystemException('injected barrier failure');
            }
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(SqliteFamily(path).inspect(), SqliteFileState.possiblyEncrypted);
      expect(
        EncryptedSqlite.probe(path, keyOf(10)),
        isA<Ok<void, SqliteStorageFailure>>(),
      );
      expectIntact(keyOf(10));
      expectNoLeftovers();
    });
  });

  group('a real filesystem failure', () {
    void readOnly(bool on) =>
        Process.runSync('chmod', [on ? '0555' : '0755', directory()]);

    tearDown(() => readOnly(false));

    test(
      'a rename refused by the filesystem leaves the plaintext database, and a retry encrypts it',
      () async {
        expect(
          () => encryptInPlace(
            SqliteFamily(path),
            keyOf(10),
            onStep: (s) {
              if (s == EncryptionStep.flushed) readOnly(true);
            },
          ),
          throwsA(isA<FileSystemException>()),
        );
        readOnly(false);
        expect(SqliteFamily(path).inspect(), SqliteFileState.plaintext);

        await encrypt(keyOf(10));
        expectIntact(keyOf(10));
        expectNoLeftovers();
      },
    );

    test(
      'a deletion refused by the filesystem keeps the marker, and a resume finishes it',
      () {
        final family = SqliteFamily(path);
        expect(
          () => retire(
            family,
            const Retirement.delete(),
            onStep: (s) {
              if (s == RetirementStep.marked) readOnly(true);
            },
          ),
          throwsA(isA<FileSystemException>()),
        );
        readOnly(false);
        expect(family.retirement.existsSync(), isTrue);
        expect(family.database.existsSync(), isTrue);

        expect(
          EncryptedSqlite.resumeRetirement(path),
          isA<Ok<bool, SqliteStorageFailure>>(),
        );
        expect(family.database.existsSync(), isFalse);
        expect(family.retirement.existsSync(), isFalse);
      },
    );
  });

  group('SIGKILL', () {
    /// The child's stdout, after checking that it was SIGKILLed — at [target] when one is given — rather than failing to start or finishing.
    /// The last step the child reported before it died, for timed kills.
    String? lastStep;

    Future<bool> runAndDie(
      String target, {
      int seed = 10,
      Duration? killAfterStart,
    }) async {
      final process = await Process.start(Platform.resolvedExecutable, [
        'run',
        'test/support/encrypt_and_die.dart',
        path,
        '$seed',
        target,
      ], workingDirectory: Directory.current.path);
      final lines = <String>[];
      final started = Completer<void>();
      final stdoutDone = process.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .forEach((line) {
            lines.add(line);
            if (line == 'started' && !started.isCompleted) started.complete();
          });
      final stderr = process.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      if (killAfterStart != null) {
        // Timed from the encryption's own start, not the process's: compiling the script takes longer than any delay here.
        await started.future;
        await Future<void>.delayed(killAfterStart);
        process.kill(ProcessSignal.sigkill);
      }
      final exitCode = await process.exitCode;
      await stdoutDone;
      final errors = await stderr;
      expect(lines, contains('started'), reason: errors);
      if (killAfterStart != null && lines.contains('completed')) {
        // The encryption beat the timer: no kill happened, and the caller knows it.
        expect(exitCode, 0, reason: errors);
        return false;
      }
      expect(lines, isNot(contains('completed')), reason: errors);
      expect(exitCode, -ProcessSignal.sigkill.signalNumber, reason: errors);
      final steps = lines.where((l) => l.startsWith('at:'));
      lastStep = steps.isEmpty ? null : steps.last.substring(3);
      if (killAfterStart == null) {
        expect(lines, contains('reached:$target'), reason: errors);
      }
      return true;
    }

    /// What the next launch does: finish the encryption if the database is still in clear, then open it.
    Future<void> relaunch(DatabaseKey key) async {
      switch (SqliteFamily(path).inspect()) {
        case SqliteFileState.plaintext:
          await encrypt(key);
        case SqliteFileState.possiblyEncrypted:
          break;
        case final other:
          fail('unexpected state after a kill: $other');
      }
      expect(
        EncryptedSqlite.probe(path, key),
        isA<Ok<void, SqliteStorageFailure>>(),
      );
    }

    for (final step in EncryptionStep.values) {
      test(
        'at ${step.name}, the next launch converges with every row',
        () async {
          final out = await runAndDie(step.name);
          expect(out, isNot(contains('completed')));
          await relaunch(keyOf(10));
          expectIntact(keyOf(10));
          expectNoLeftovers();
        },
      );
    }

    test(
      'mid-copy and mid-rekey on a larger database, at random points',
      () async {
        final db = sqlite3.open(path, mode: OpenMode.readWrite);
        final insert = db.prepare(
          'INSERT INTO labels (label, payload) VALUES (?, ?);',
        );
        final random = Random(7);
        db.execute('BEGIN;');
        for (var i = 0; i < 60000; i++) {
          insert.execute([
            'bulk $i',
            Uint8List.fromList(List.generate(400, (_) => random.nextInt(256))),
          ]);
        }
        db.execute('COMMIT;');
        insert.close();
        db.close();
        rows += 60000;

        var killed = 0;
        var insideCopyOrRekey = 0;
        for (final ms in [1, 5, 15, 40, 100, 200, 400, 800]) {
          if (SqliteFamily(path).inspect() != SqliteFileState.plaintext) break;
          if (await runAndDie(
            'never',
            killAfterStart: Duration(milliseconds: ms),
          )) {
            killed++;
            // Killed after the source settled and before the copy was verified: inside VACUUM INTO or PRAGMA rekey.
            if (const {'staleCandidateRemoved', 'copied'}.contains(lastStep)) {
              insideCopyOrRekey++;
            }
          }
        }
        // At least one kill landed inside the encryption, not after it.
        expect(killed, greaterThan(0));
        expect(insideCopyOrRekey, greaterThan(0));
        await relaunch(keyOf(10));
        expectIntact(keyOf(10));
        expectNoLeftovers();
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'a candidate left under another key is discarded, and the new key wins',
      () async {
        await runAndDie(EncryptionStep.rekeyed.name, seed: 20);
        expect(SqliteFamily(path).candidate.existsSync(), isTrue);
        await relaunch(keyOf(30));
        expectIntact(keyOf(30));
        expect(
          EncryptedSqlite.probe(path, keyOf(20)),
          isA<Err<void, SqliteStorageFailure>>(),
        );
        expectNoLeftovers();
      },
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
