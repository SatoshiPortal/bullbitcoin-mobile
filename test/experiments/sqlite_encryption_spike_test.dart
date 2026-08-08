import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('SQLite3MultipleCiphers encrypts a migrated WAL database', () async {
    final directory = await Directory.systemTemp.createTemp('sqlite-spike-');
    addTearDown(() => directory.delete(recursive: true));

    final plaintext = File('${directory.path}/plaintext.sqlite');
    final encrypted = File('${directory.path}/encrypted.sqlite');
    final temporary = File('${encrypted.path}.tmp');
    const key = 'test-only-database-key';
    const marker = 'secret-swap-preimage-marker';

    final plaintextDb = sqlite3.open(plaintext.path);
    try {
      _requireCipherSupport(plaintextDb);
      plaintextDb.execute('PRAGMA journal_mode = WAL;');
      plaintextDb.execute('CREATE TABLE swaps (preimage TEXT NOT NULL);');
      plaintextDb.execute("INSERT INTO swaps VALUES ('$marker');");
      plaintextDb.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      plaintextDb.execute("VACUUM INTO '${_escape(temporary.path)}';");
    } finally {
      plaintextDb.close();
    }

    final copyDb = sqlite3.open(temporary.path);
    try {
      _requireCipherSupport(copyDb);
      copyDb.execute("PRAGMA rekey = '${_escape(key)}';");
    } finally {
      copyDb.close();
    }
    await temporary.rename(encrypted.path);

    final unkeyedDb = sqlite3.open(encrypted.path);
    try {
      expect(
        () => unkeyedDb.select('SELECT preimage FROM swaps;'),
        throwsA(isA<Exception>()),
      );
    } finally {
      unkeyedDb.close();
    }

    final encryptedDb = sqlite3.open(encrypted.path);
    try {
      _requireCipherSupport(encryptedDb);
      encryptedDb.execute("PRAGMA key = '${_escape(key)}';");
      expect(
        encryptedDb.select('SELECT preimage FROM swaps;').single['preimage'],
        marker,
      );
      encryptedDb.execute('PRAGMA journal_mode = WAL;');
      encryptedDb.execute("INSERT INTO swaps VALUES ('$marker-wal');");
    } finally {
      encryptedDb.close();
    }

    await _expectNoPlaintextMarker(encrypted, marker);
    final wal = File('${encrypted.path}-wal');
    if (await wal.exists()) {
      await _expectNoPlaintextMarker(wal, marker);
    }
  });

  test('drift_flutter applies the key in its database isolate', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final directory = await Directory.systemTemp.createTemp('drift-spike-');
    addTearDown(() => directory.delete(recursive: true));

    final databaseFile = File('${directory.path}/bullbitcoin_sqlite.sqlite');
    const key = 'test-only-drift-key';

    final database = SqliteDatabase(
      driftDatabase(
        name: 'encrypted-drift-spike',
        native: DriftNativeOptions(
          databasePath: () async => databaseFile.path,
          tempDirectoryPath: () async => directory.path,
          shareAcrossIsolates: true,
          setup: (rawDb) {
            final nativeDb = rawDb as Database;
            _requireCipherSupport(nativeDb);
            nativeDb.execute("PRAGMA key = '${_escape(key)}';");
          },
        ),
      ),
    );
    try {
      expect((await database.customSelect('SELECT 1;').get()).single.data, {
        '1': 1,
      });
    } finally {
      await database.close();
    }

    final encryptedDb = sqlite3.open(databaseFile.path);
    try {
      _requireCipherSupport(encryptedDb);
      encryptedDb.execute("PRAGMA key = '${_escape(key)}';");
      expect(
        encryptedDb
            .select("SELECT name FROM sqlite_master WHERE name = 'settings';")
            .single['name'],
        'settings',
      );
    } finally {
      encryptedDb.close();
    }
    await _expectNoPlaintextMarker(databaseFile, 'SQLite format 3');
  });

  test(
    'manually spawned Drift isolate applies the key before opening',
    () async {
      final directory = await Directory.systemTemp.createTemp('spawned-spike-');
      addTearDown(() => directory.delete(recursive: true));

      final databaseFile = File('${directory.path}/bullbitcoin_sqlite.sqlite');
      const key = 'test-only-spawned-isolate-key';

      final isolate = await DriftIsolate.spawn(() {
        return NativeDatabase(
          databaseFile,
          setup: (rawDb) {
            _requireCipherSupport(rawDb);
            rawDb.execute("PRAGMA key = '${_escape(key)}';");
          },
        );
      });
      final database = SqliteDatabase(
        await isolate.connect(singleClientMode: true),
      );
      try {
        expect(await database.customSelect('SELECT 1;').get(), hasLength(1));
      } finally {
        await database.close();
      }

      final encryptedDb = sqlite3.open(databaseFile.path);
      try {
        _requireCipherSupport(encryptedDb);
        encryptedDb.execute("PRAGMA key = '${_escape(key)}';");
        expect(
          encryptedDb
              .select("SELECT name FROM sqlite_master WHERE name = 'settings';")
              .single['name'],
          'settings',
        );
      } finally {
        encryptedDb.close();
      }
    },
  );

  test(
    'migrates the current Drift schema and its data to encryption',
    () async {
      final directory = await Directory.systemTemp.createTemp('schema-spike-');
      addTearDown(() => directory.delete(recursive: true));

      final plaintext = File('${directory.path}/plaintext.sqlite');
      final encrypted = File('${directory.path}/encrypted.sqlite');
      const key = 'test-only-schema-key';
      const marker = 'schema-data-survives-encryption';

      final plaintextDb = SqliteDatabase(
        NativeDatabase.createInBackground(
          plaintext,
          setup: (rawDb) {
            rawDb.execute('PRAGMA journal_mode = WAL;');
          },
        ),
      );
      try {
        await plaintextDb.customStatement(
          'CREATE TABLE encryption_spike (value TEXT NOT NULL);',
        );
        await plaintextDb.customStatement(
          "INSERT INTO encryption_spike VALUES ('$marker');",
        );
      } finally {
        await plaintextDb.close();
      }

      await _encryptPlaintextDatabase(
        plaintext: plaintext,
        encrypted: encrypted,
        key: key,
      );

      final encryptedDb = SqliteDatabase(
        NativeDatabase.createInBackground(
          encrypted,
          setup: (rawDb) {
            _requireCipherSupport(rawDb);
            rawDb.execute("PRAGMA key = '${_escape(key)}';");
          },
        ),
      );
      try {
        final row =
            (await encryptedDb
                    .customSelect('SELECT value FROM encryption_spike;')
                    .get())
                .single;
        expect(row.data['value'], marker);
      } finally {
        await encryptedDb.close();
      }
      await _expectNoPlaintextMarker(encrypted, marker);
    },
  );
}

void _requireCipherSupport(Database database) {
  if (database.select('PRAGMA cipher;').isEmpty) {
    throw StateError(
      'The sqlite3mc build hook did not load an encrypted SQLite',
    );
  }
}

Future<void> _expectNoPlaintextMarker(File file, String marker) async {
  final contents = latin1.decode(await file.readAsBytes());
  expect(contents, isNot(contains(marker)));
  expect(contents, isNot(contains('SQLite format 3')));
}

Future<void> _encryptPlaintextDatabase({
  required File plaintext,
  required File encrypted,
  required String key,
}) async {
  final temporary = File('${encrypted.path}.tmp');
  final plaintextDb = sqlite3.open(plaintext.path);
  try {
    plaintextDb.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    plaintextDb.execute("VACUUM INTO '${_escape(temporary.path)}';");
  } finally {
    plaintextDb.close();
  }

  final copyDb = sqlite3.open(temporary.path);
  try {
    _requireCipherSupport(copyDb);
    copyDb.execute("PRAGMA rekey = '${_escape(key)}';");
  } finally {
    copyDb.close();
  }
  await temporary.rename(encrypted.path);
}

String _escape(String value) => value.replaceAll("'", "''");
