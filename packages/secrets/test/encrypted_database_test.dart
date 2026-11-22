import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late File file;
  late _Store store;
  late DatabaseKeys keys;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('encrypted-drift-');
    file = File('${directory.path}/sample.sqlite');
    store = _Store()..install();
    keys = Secrets(scratchDirectory: () async => directory.path)
        .databaseKeys(module: 'recipe_test');
  });

  tearDown(() => directory.delete(recursive: true));

  Future<Result<QueryExecutor, DatabaseOpenFailure>> open({int? background}) =>
      keys.open(name: 'sample', file: file, existingSchemaVersion: background);

  Future<void> writeSample() async {
    final Ok(:value) = (await open()) as Ok<QueryExecutor, DatabaseOpenFailure>;
    final db = _SampleDatabase(value);
    try {
      await db.customStatement("INSERT INTO sample VALUES ('local fixture')");
    } finally {
      await db.close();
    }
  }

  test(
    'encrypts from the first write and reopens the current schema',
    () async {
      await writeSample();
      final unkeyed = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        expect(
          () => unkeyed.select('SELECT * FROM sample'),
          throwsA(isA<SqliteException>()),
        );
      } finally {
        unkeyed.close();
      }
      expect(
        String.fromCharCodes((await file.readAsBytes()).take(16)),
        isNot('SQLite format 3\u0000'),
      );
      final Ok(:value) =
          (await open(background: 1)) as Ok<QueryExecutor, DatabaseOpenFailure>;
      final db = _SampleDatabase(value);
      try {
        final row = await db
            .customSelect('SELECT data FROM sample')
            .getSingle();
        expect(row.read<String>('data'), 'local fixture');
        expect(store.writes, 1);
      } finally {
        await db.close();
      }
    },
  );

  test('background never creates a file or upgrades the schema', () async {
    expect(
      await open(background: 1),
      isA<Err<QueryExecutor, DatabaseOpenFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<DatabaseNotReady>(),
      ),
    );
    expect(await file.exists(), isFalse);
    expect(store.entries, isEmpty);
    await writeSample();
    expect(
      await open(background: 2),
      isA<Err<QueryExecutor, DatabaseOpenFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<DatabaseNotReady>(),
      ),
    );
    expect(store.writes, 1);
  });

  test('locked and missing keys preserve the existing ciphertext', () async {
    await writeSample();
    final original = await file.readAsBytes();
    store.locked = true;
    expect(await open(), _hasKeyProblem(DatabaseKeyProblem.locked));
    store.locked = false;
    store.entries.clear();
    expect(await open(), _hasKeyProblem(DatabaseKeyProblem.missing));
    expect(store.writes, 1);
    expect(await file.readAsBytes(), original);
  });

  test(
    'key read-back must succeed before a fresh database is created',
    () async {
      final unreadable = _Store(lockAfterWrite: true)..install();
      expect(await open(), _hasKeyProblem(DatabaseKeyProblem.locked));
      expect(await file.exists(), isFalse);
      expect(unreadable.writes, 1);
      unreadable.locked = false;
      await writeSample();
      expect(unreadable.writes, 1);
    },
  );

  test('a pre-existing plaintext file is preserved', () async {
    final plaintext = sqlite3.open(file.path);
    plaintext.execute('CREATE TABLE sample (data TEXT)');
    plaintext.close();
    final original = await file.readAsBytes();
    expect(await keys.getOrCreate(name: 'sample'), isA<Ok>());
    expect(
      await open(),
      isA<Err<QueryExecutor, DatabaseOpenFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<DatabaseFileUnavailable>(),
      ),
    );
    expect(await file.readAsBytes(), original);
    expect(store.writes, 1);
  });

  test('wrong key refuses to open and is never replaced', () async {
    await writeSample();
    final original = await file.readAsBytes();
    // Reprovision a different key through the real API in a separate store.
    final unrelated = _Store()..install();
    expect(await keys.getOrCreate(name: 'sample'), isA<Ok>());
    expect(
      await open(),
      isA<Err<QueryExecutor, DatabaseOpenFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<DatabaseFileUnavailable>().having(
          (f) => f.reason,
          'reason',
          DatabaseFileProblem.unreadable,
        ),
      ),
    );
    expect(unrelated.writes, 1);
    expect(await file.readAsBytes(), original);
  });

  test('orphaned sidecars and pending retirement block creation', () async {
    for (final suffix in ['-wal', '-shm', '-journal', '.retire-pending']) {
      final sidecar = await File('${file.path}$suffix').create();
      expect(
        await open(),
        isA<Err<QueryExecutor, DatabaseOpenFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<DatabaseFileUnavailable>().having(
            (f) => f.reason,
            'reason',
            DatabaseFileProblem.inconsistent,
          ),
        ),
      );
      expect(await sidecar.exists(), isTrue);
      await sidecar.delete();
    }
    expect(await file.exists(), isFalse);
    expect(store.entries, isEmpty);
  });
}

Matcher _hasKeyProblem(DatabaseKeyProblem reason) =>
    isA<Err<QueryExecutor, DatabaseOpenFailure>>().having(
      (r) => r.failure,
      'failure',
      isA<DatabaseKeyUnavailable>().having((f) => f.reason, 'reason', reason),
    );

class _SampleDatabase extends GeneratedDatabase {
  _SampleDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement('CREATE TABLE sample (data TEXT)'),
  );
}

final class _Store extends FakeSecureStoragePlatform {
  final bool lockAfterWrite;
  int writes = 0;

  _Store({this.lockAfterWrite = false});

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    await super.write(key: key, value: value, options: options);
    writes++;
    if (lockAfterWrite) locked = true;
  }
}
