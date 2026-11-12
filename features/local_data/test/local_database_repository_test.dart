import 'dart:io';

import 'package:bull_local_data/src/data/local_database_repository_impl.dart';
import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:bull_local_data/src/domain/usecases/unlock_local_databases_usecase.dart';
import 'package:bull_sqlite/bull_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

/// The real `secrets` package against an in-memory keystore installed at the plugin's own seam, and real files encrypted by SQLite3MultipleCiphers.
void main() {
  const mainKey = 'com.bullbitcoin.secrets/dek/bb_mobile/bullbitcoin_sqlite';
  const payjoinKey = 'com.bullbitcoin.secrets/dek/bull_payjoin/payjoin';
  const canary = 'CANARY-local-data-41f0';

  late Directory directory;
  late LocalDatabasePaths paths;
  late FakeSecureStoragePlatform storage;
  late LocalDatabaseRepositoryImpl repository;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('local_data_');
    paths = LocalDatabasePaths(
      main: '${directory.path}/bullbitcoin_sqlite.sqlite',
      payjoin: '${directory.path}/payjoin.sqlite',
    );
    storage = FakeSecureStoragePlatform()..install();
    repository = LocalDatabaseRepositoryImpl(
      secrets: Secrets(scratchDirectory: () async => directory.path),
      paths: paths,
    );
  });
  tearDown(() => directory.deleteSync(recursive: true));

  void seedPlaintext(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA user_version = 16;');
    db.execute('CREATE TABLE labels (label TEXT);');
    db.execute("INSERT INTO labels VALUES ('$canary');");
    db.close();
  }

  String header(String path) =>
      String.fromCharCodes(File(path).readAsBytesSync().take(15));

  String readCanary(String path, DatabaseKey key) {
    final db = sqlite3.open(path, mode: OpenMode.readWrite);
    addTearDown(db.close);
    SqliteCipher.key(db, key);
    return db.select('SELECT label FROM labels;').single['label'] as String;
  }

  Future<UnlockedDatabase> unlocked(LocalDatabase database) async =>
      switch (await repository.unlock(database)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('unlock failed: $failure'),
      };

  Future<LocalDataFailure> failed(LocalDatabase database) async =>
      switch (await repository.unlock(database)) {
        Ok() => fail('expected a failure'),
        Err(:final failure) => failure,
      };

  test('a first start creates one key per database and nothing else', () async {
    final result = await UnlockLocalDatabasesUsecase(repository).execute();
    expect(result, isA<Ok<UnlockedDatabases, LocalDataFailure>>());
    expect(storage.entries.keys, containsAll([mainKey, payjoinKey]));
    expect(File(paths.main).existsSync(), isFalse);
  });

  test('an upgrade encrypts the plaintext databases with every row', () async {
    seedPlaintext(paths.main);
    seedPlaintext(paths.payjoin);

    final main = await unlocked(LocalDatabase.main);
    final payjoin = await unlocked(LocalDatabase.payjoin);

    for (final db in [main, payjoin]) {
      expect(header(db.path), isNot('SQLite format 3'));
      expect(readCanary(db.path, db.key), canary);
    }
    expect(main.key.hex, isNot(payjoin.key.hex));
  });

  test('the next start reads the same key and opens the database', () async {
    seedPlaintext(paths.main);
    final first = await unlocked(LocalDatabase.main);
    final second = await unlocked(LocalDatabase.main);
    expect(second.key.hex, first.key.hex);
    expect(readCanary(paths.main, second.key), canary);
  });

  test(
    'an encrypted database whose key is gone is refused, and no key is created',
    () async {
      seedPlaintext(paths.main);
      await unlocked(LocalDatabase.main);
      storage.entries.remove(mainKey);

      expect(
        await failed(LocalDatabase.main),
        isA<LocalDataKeyMissingFailure>(),
      );
      expect(storage.entries.containsKey(mainKey), isFalse);
      expect(header(paths.main), isNot('SQLite format 3'));
    },
  );

  test('a false absence of the key is not believed', () async {
    seedPlaintext(paths.main);
    final first = await unlocked(LocalDatabase.main);
    final stored = storage.entries[mainKey];
    // The keystore answers "absent" three times before the value comes.
    storage.scripted.addAll([null, null, null, stored]);

    final again = await unlocked(LocalDatabase.main);
    expect(again.key.hex, first.key.hex);
  });

  group('a locked keystore', () {
    test(
      'on an encrypted database asks for a retry and writes nothing',
      () async {
        seedPlaintext(paths.main);
        await unlocked(LocalDatabase.main);
        final before = Map.of(storage.entries);
        storage.locked = true;

        expect(
          await failed(LocalDatabase.main),
          isA<LocalDataKeystoreLockedFailure>(),
        );
        expect(storage.entries, before);
      },
    );

    test('on a first start creates no key', () async {
      storage.locked = true;
      expect(
        await failed(LocalDatabase.main),
        isA<LocalDataKeystoreLockedFailure>(),
      );
      expect(storage.entries, isEmpty);
    });

    test(
      'on a plaintext database leaves it in clear and creates no key',
      () async {
        seedPlaintext(paths.main);
        storage.locked = true;
        expect(
          await failed(LocalDatabase.main),
          isA<LocalDataKeystoreLockedFailure>(),
        );
        expect(storage.entries, isEmpty);
        expect(header(paths.main), 'SQLite format 3');
      },
    );
  });

  test('a corrupt key is reported and kept, never replaced', () async {
    seedPlaintext(paths.main);
    await unlocked(LocalDatabase.main);
    storage.entries[mainKey] = 'not a key';

    expect(await failed(LocalDatabase.main), isA<LocalDataKeyCorruptFailure>());
    expect(storage.entries[mainKey], 'not a key');
  });

  test('a database its key does not open is unreadable, and untouched', () async {
    seedPlaintext(paths.main);
    await unlocked(LocalDatabase.main);
    final bytes = File(paths.main).readAsBytesSync();
    // Another key under the same name: what a key restored from elsewhere would look like.
    storage.entries.remove(mainKey);
    final keys = Secrets(
      scratchDirectory: () async => directory.path,
    ).databaseKeys(module: 'bb_mobile');
    expect(
      await keys.getOrCreate(name: 'bullbitcoin_sqlite'),
      isA<Ok<DatabaseKey, SecretFailure>>(),
    );

    expect(await failed(LocalDatabase.main), isA<LocalDataUnreadableFailure>());
    expect(File(paths.main).readAsBytesSync(), bytes);
  });

  test(
    'files in an undecidable state are left alone, and no key is created',
    () async {
      File('${paths.main}-wal').writeAsStringSync('orphan');
      expect(
        await failed(LocalDatabase.main),
        isA<LocalDataInconsistentFailure>(),
      );
      expect(storage.entries, isEmpty);
      expect(File('${paths.main}-wal').readAsStringSync(), 'orphan');
    },
  );

  test(
    'an unreadable Payjoin database names Payjoin, and the main one still opens',
    () async {
      seedPlaintext(paths.main);
      seedPlaintext(paths.payjoin);
      final main = await unlocked(LocalDatabase.main);
      await unlocked(LocalDatabase.payjoin);
      storage.entries.remove(payjoinKey);

      final failure = await UnlockLocalDatabasesUsecase(repository).execute();
      expect(
        (failure as Err<UnlockedDatabases, LocalDataFailure>).failure,
        isA<LocalDataKeyMissingFailure>().having(
          (f) => f.database,
          'database',
          LocalDatabase.payjoin,
        ),
      );
      expect(readCanary(paths.main, main.key), canary);
    },
  );

  group('reset', () {
    test(
      'erases the database and its key, and the next start begins afresh',
      () async {
        seedPlaintext(paths.main);
        seedPlaintext(paths.payjoin);
        await unlocked(LocalDatabase.main);
        final payjoin = await unlocked(LocalDatabase.payjoin);
        storage.entries.remove(mainKey);
        expect(
          await failed(LocalDatabase.main),
          isA<LocalDataKeyMissingFailure>(),
        );

        expect(
          await repository.reset(LocalDatabase.main),
          isA<Ok<void, LocalDataFailure>>(),
        );

        expect(File(paths.main).existsSync(), isFalse);
        expect(File('${paths.main}.retire-pending').existsSync(), isFalse);
        expect(await unlocked(LocalDatabase.main), isA<UnlockedDatabase>());
        // The readable Payjoin database and its key were not touched.
        expect(readCanary(paths.payjoin, payjoin.key), canary);
        expect(storage.entries.containsKey(payjoinKey), isTrue);
      },
    );

    test('removes a corrupt key, so the next start can create one', () async {
      seedPlaintext(paths.main);
      await unlocked(LocalDatabase.main);
      storage.entries[mainKey] = 'not a key';

      expect(
        await repository.reset(LocalDatabase.main),
        isA<Ok<void, LocalDataFailure>>(),
      );
      expect(storage.entries.containsKey(mainKey), isFalse);
      expect(await unlocked(LocalDatabase.main), isA<UnlockedDatabase>());
    });

    test(
      'interrupted after its marker, it is finished at the next start',
      () async {
        seedPlaintext(paths.main);
        await unlocked(LocalDatabase.main);
        File('${paths.main}.retire-pending').writeAsStringSync('delete');

        final reopened = await unlocked(LocalDatabase.main);
        expect(File('${paths.main}.retire-pending').existsSync(), isFalse);
        expect(File(paths.main).existsSync(), isFalse);
        expect(reopened.key, isA<DatabaseKey>());
      },
    );
  });
}
