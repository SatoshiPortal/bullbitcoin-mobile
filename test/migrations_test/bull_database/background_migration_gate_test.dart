import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'generated/schema_v13.dart' as v13;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bull_gate');
    file = File('${dir.path}/${SqliteDatabase.name}.sqlite');
  });

  tearDown(() => dir.delete(recursive: true));

  // Background tasks run only when this is true, so that only the foreground
  // app ever migrates the database (#3045).
  group('isFileAtCurrentSchema', () {
    test('is false, and creates nothing, when the database does not exist', () {
      expect(SqliteDatabase.isFileAtCurrentSchema(file), isFalse);
      expect(file.existsSync(), isFalse);
    });

    test(
      'is false, and migrates nothing, while the database needs migrating',
      () async {
        final seeded = v13.DatabaseAtV13(NativeDatabase(file));
        await seeded.customSelect('SELECT 1').get();
        await seeded.close();

        expect(SqliteDatabase.isFileAtCurrentSchema(file), isFalse);
        expect(_userVersion(file), 13);
      },
    );

    test('is true once the app has migrated the database', () async {
      final db = SqliteDatabase(NativeDatabase(file));
      await db.customSelect('SELECT 1').get();
      await db.close();

      expect(SqliteDatabase.isFileAtCurrentSchema(file), isTrue);
    });

    test('is false for a database from a newer schema', () async {
      final db = SqliteDatabase(NativeDatabase(file));
      await db.customSelect('SELECT 1').get();
      await db.close();
      final raw = sqlite3.open(file.path);
      raw.userVersion = SqliteDatabase.currentSchemaVersion + 1;
      raw.dispose();

      expect(SqliteDatabase.isFileAtCurrentSchema(file), isFalse);
    });

    test('reads the version while the app holds the database open in WAL '
        'mode', () async {
      final db = SqliteDatabase(
        NativeDatabase(
          file,
          setup: (database) {
            database.execute('PRAGMA busy_timeout = 2000;');
            database.execute('PRAGMA journal_mode = WAL;');
          },
        ),
      );
      await db.customSelect('SELECT 1').get();

      expect(SqliteDatabase.isFileAtCurrentSchema(file), isTrue);
      await db.close();
    });
  });
}

int _userVersion(File file) {
  final db = sqlite3.open(file.path);
  try {
    return db.userVersion;
  } finally {
    db.dispose();
  }
}
