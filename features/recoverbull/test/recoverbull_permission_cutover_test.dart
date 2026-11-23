import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/migration.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_server_url.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

typedef _LegacyConsent = ({bool permissionGranted, String sourceUrl});

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

  test('an unadopted v1 singleton leaves consent to the v16 source', () async {
    final source = _openV1(file);
    try {
      source.execute('INSERT INTO recoverbull_state DEFAULT VALUES');
    } finally {
      source.close();
    }

    expect(
      await readLegacyRecoverBullPermission(file),
      isA<Ok<_LegacyConsent?, RecoverBullFailure>>().having(
        (r) => r.value,
        'permission',
        null,
      ),
    );
  });

  test('absence stays distinct from explicit denial', () async {
    expect(
      await readLegacyRecoverBullPermission(file),
      isA<Ok<_LegacyConsent?, RecoverBullFailure>>().having(
        (r) => r.value,
        'permission',
        null,
      ),
    );
    final source = _openV1(file);
    try {
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Ok<_LegacyConsent?, RecoverBullFailure>>().having(
          (r) => r.value,
          'permission',
          null,
        ),
      );
      source.execute(
        'INSERT INTO recoverbull_state (legacy_import_complete) VALUES (1)',
      );
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Ok<_LegacyConsent?, RecoverBullFailure>>().having(
          (r) => r.value?.permissionGranted,
          'permission',
          false,
        ),
      );
      source.execute('UPDATE recoverbull_state SET permission_granted = 1');
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Ok<_LegacyConsent?, RecoverBullFailure>>().having(
          (r) => r.value?.permissionGranted,
          'permission',
          true,
        ),
      );
      source.execute('PRAGMA ignore_check_constraints = ON');
      source.execute('UPDATE recoverbull_state SET permission_granted = 2');
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Err<_LegacyConsent?, RecoverBullFailure>>(),
      );
    } finally {
      source.close();
    }
  });

  test('an orphaned WAL does not fall back to the historical root', () async {
    File('${file.path}-wal').createSync();
    expect(
      await readLegacyRecoverBullPermission(file),
      isA<Err<_LegacyConsent?, RecoverBullFailure>>(),
    );
  });

  test('a future schema does not fall back to the historical root', () async {
    final source = sqlite3.open(file.path);
    try {
      source.userVersion = 2;
      expect(
        await readLegacyRecoverBullPermission(file),
        isA<Err<_LegacyConsent?, RecoverBullFailure>>(),
      );
      expect(source.userVersion, 2);
    } finally {
      source.close();
    }
  });

  test('reading consent preserves the standalone database bytes', () async {
    final source = _openV1(file);
    try {
      source.execute(
        'INSERT INTO recoverbull_state '
        '(permission_granted, legacy_import_complete) VALUES (1, 1)',
      );
    } finally {
      source.close();
    }
    final before = await file.readAsBytes();
    expect(
      await readLegacyRecoverBullPermission(file),
      isA<Ok<_LegacyConsent?, RecoverBullFailure>>().having(
        (result) => result.value?.permissionGranted,
        'permission',
        true,
      ),
    );
    expect(await file.readAsBytes(), before);
  });
}

Database _openV1(File file) {
  final source = sqlite3.open(file.path);
  source.userVersion = 1;
  source.execute('''
    CREATE TABLE recoverbull_state (
      id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY CHECK (id = 1),
      server TEXT NOT NULL DEFAULT '$recoverBullDefaultServerUrl',
      permission_granted INTEGER NOT NULL DEFAULT 0
        CHECK (permission_granted IN (0, 1)),
      monitoring_enabled INTEGER NOT NULL DEFAULT 1
        CHECK (monitoring_enabled IN (0, 1)),
      legacy_import_complete INTEGER NOT NULL DEFAULT 0
        CHECK (legacy_import_complete IN (0, 1)),
      monitoring_revision INTEGER NOT NULL DEFAULT 0,
      generation INTEGER NOT NULL DEFAULT 0 CHECK (generation >= 0)
    )
  ''');
  return source;
}
