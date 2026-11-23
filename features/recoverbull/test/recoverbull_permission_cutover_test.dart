import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'recoverbull-permission-',
    );
    file = File('${directory.path}/recoverbull.sqlite');
  });

  tearDown(() => directory.delete(recursive: true));

  test('absence stays distinct from explicit denial', () async {
    expect(
      await readLegacyRecoverBullPermission(file),
      isA<Ok<bool?, RecoverBullFailure>>().having(
        (r) => r.value,
        'permission',
        null,
      ),
    );
    final source = sqlite3.open(file.path);
    try {
      source.userVersion = 1;
      source.execute('''
        CREATE TABLE recoverbull_state (
          id INTEGER PRIMARY KEY,
          permission_granted INTEGER NOT NULL
        )
      ''');
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Ok<bool?, RecoverBullFailure>>().having(
          (r) => r.value,
          'permission',
          null,
        ),
      );
      source.execute('INSERT INTO recoverbull_state VALUES (1, 0)');
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Ok<bool?, RecoverBullFailure>>().having(
          (r) => r.value,
          'permission',
          false,
        ),
      );
      source.execute('UPDATE recoverbull_state SET permission_granted = 1');
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Ok<bool?, RecoverBullFailure>>().having(
          (r) => r.value,
          'permission',
          true,
        ),
      );
      source.execute('UPDATE recoverbull_state SET permission_granted = 2');
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Err<bool?, RecoverBullFailure>>(),
      );
    } finally {
      source.close();
    }
  });

  test('an orphaned WAL does not fall back to the historical root', () async {
    File('${file.path}-wal').createSync();
    expect(
      await readLegacyRecoverBullPermission(file),
      isA<Err<bool?, RecoverBullFailure>>(),
    );
  });

  test('a future schema does not fall back to the historical root', () async {
    final source = sqlite3.open(file.path);
    try {
      source.userVersion = 2;
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Err<bool?, RecoverBullFailure>>(),
      );
      expect(source.userVersion, 2);
    } finally {
      source.close();
    }
  });

  test('reading consent preserves the standalone database bytes', () async {
    final source = sqlite3.open(file.path);
    try {
      source.userVersion = 1;
      source.execute(
        'CREATE TABLE recoverbull_state ('
        'id INTEGER PRIMARY KEY, permission_granted INTEGER NOT NULL)',
      );
      source.execute('INSERT INTO recoverbull_state VALUES (1, 1)');
    } finally {
      source.close();
    }
    final before = await file.readAsBytes();
    expect(
      await readLegacyRecoverBullPermission(file),
      isA<Ok<bool?, RecoverBullFailure>>().having(
        (result) => result.value,
        'permission',
        true,
      ),
    );
    expect(await file.readAsBytes(), before);
  });
}
