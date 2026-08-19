import 'dart:convert';
import 'dart:io';

import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// `payjoin.sqlite` ships encrypted from its first byte: the package is
/// unreleased, so there is no plaintext population to migrate and no unkeyed
/// way to open it.
void main() {
  late Directory directory;
  late File databaseFile;

  const key = 'test-only-payjoin-key';
  const marker = 'payjoin-original-psbt-marker';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('payjoin-encrypted-');
    databaseFile = File('${directory.path}/payjoin.sqlite');
  });

  tearDown(() => directory.delete(recursive: true));

  Future<void> writeMarker() async {
    final database = PayjoinDatabase.open(
      databaseFile.path,
      encryptionKey: key,
    );
    try {
      await database.customStatement(
        'CREATE TABLE encryption_probe (value TEXT NOT NULL);',
      );
      await database.customStatement(
        "INSERT INTO encryption_probe VALUES ('$marker');",
      );
    } finally {
      await database.close();
    }
  }

  test('a freshly created Payjoin database is encrypted on disk', () async {
    await writeMarker();

    final contents = latin1.decode(await databaseFile.readAsBytes());
    expect(contents, isNot(contains('SQLite format 3')));
    expect(contents, isNot(contains(marker)));
  });

  test('the Payjoin database reopens with its key', () async {
    await writeMarker();

    final database = PayjoinDatabase.open(
      databaseFile.path,
      encryptionKey: key,
    );
    try {
      final row =
          (await database
                  .customSelect('SELECT value FROM encryption_probe;')
                  .get())
              .single;
      expect(row.data['value'], marker);
    } finally {
      await database.close();
    }
  });

  test('the Payjoin database cannot be read without its key', () async {
    await writeMarker();

    final database = sqlite3.open(databaseFile.path);
    try {
      expect(
        () => database.select('SELECT value FROM encryption_probe;'),
        throwsA(isA<Exception>()),
      );
    } finally {
      database.close();
    }
  });
}
