import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema_v13.dart' as v13;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // The foreground app and a WorkManager background task can open the
  // database at the same moment, each on its own drift connection, and both
  // run the pending migrations. drift runs them without a transaction and
  // writes user_version after each step, so the slower connection can write a
  // stale version and re-run steps whose DDL is already applied. Every step
  // must be idempotent or the next launch crashes forever (#3045). The
  // fixture holds no rows, so this only proves each step's DDL can be
  // re-executed; data a step copies or rewrites needs its own re-run test.
  test('two connections migrating concurrently from schema 13 leave the '
      'database at the current schema', () async {
    final dir = await Directory.systemTemp.createTemp('bull_migration_race');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/${SqliteDatabase.name}.sqlite');
    QueryExecutor connection() => NativeDatabase(
      file,
      setup: (database) {
        database.execute('PRAGMA busy_timeout = 2000;');
        database.execute('PRAGMA journal_mode = WAL;');
      },
    );

    final seeded = v13.DatabaseAtV13(connection());
    await seeded.customSelect('SELECT 1').get();
    await seeded.close();

    final foreground = SqliteDatabase(connection());
    final background = SqliteDatabase(connection());
    await Future.wait([
      foreground.customSelect('SELECT 1').get(),
      background.customSelect('SELECT 1').get(),
    ]);
    await foreground.close();
    await background.close();

    final relaunch = SqliteDatabase(connection());
    final userVersion = await relaunch
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    expect(userVersion, SqliteDatabase.currentSchemaVersion);
    await relaunch.close();
  });
}
