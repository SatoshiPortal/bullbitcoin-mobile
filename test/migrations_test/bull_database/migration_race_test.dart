import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v10.dart' as v10;
import 'generated/schema_v11.dart' as v11;
import 'generated/schema_v12.dart' as v12;
import 'generated/schema_v13.dart' as v13;
import 'generated/schema_v14.dart' as v14;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;
import 'generated/schema_v9.dart' as v9;

final _fixtures = <int, GeneratedDatabase Function(QueryExecutor)>{
  1: v1.DatabaseAtV1.new,
  2: v2.DatabaseAtV2.new,
  3: v3.DatabaseAtV3.new,
  4: v4.DatabaseAtV4.new,
  5: v5.DatabaseAtV5.new,
  6: v6.DatabaseAtV6.new,
  7: v7.DatabaseAtV7.new,
  8: v8.DatabaseAtV8.new,
  9: v9.DatabaseAtV9.new,
  10: v10.DatabaseAtV10.new,
  11: v11.DatabaseAtV11.new,
  12: v12.DatabaseAtV12.new,
  13: v13.DatabaseAtV13.new,
  14: v14.DatabaseAtV14.new,
};

const _labelCount = 5;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // drift does not serialize migrations across connections and writes
  // user_version after each step commits, so when two connections migrate the
  // same file the slower one can write a stale version and re-run steps over a
  // database that is already further along (#3045). Either connection may
  // fail; the next launch must reach the current schema intact.
  for (final MapEntry(key: version, value: fixture) in _fixtures.entries) {
    for (final background in [false, true]) {
      final mode = background ? 'separate isolates' : 'one isolate';
      test('two connections migrating concurrently from schema $version '
          '($mode) leave the next launch at the current schema with every '
          'label', () async {
        for (var run = 0; run < (background ? 10 : 1); run++) {
          final dir = await Directory.systemTemp.createTemp('bull_race');
          addTearDown(() => dir.delete(recursive: true));
          final file = File('${dir.path}/${SqliteDatabase.name}.sqlite');

          final seeded = fixture(NativeDatabase(file));
          await seeded.customSelect('SELECT 1').get();
          await seeded.close();
          _seedLabels(file, version);

          await Future.wait([
            _openIgnoringFailure(_connection(file, background: background)),
            _openIgnoringFailure(_connection(file, background: background)),
          ]);

          final relaunch = SqliteDatabase(_connection(file));
          final userVersion = await relaunch
              .customSelect('PRAGMA user_version')
              .map((row) => row.read<int>('user_version'))
              .getSingle();
          expect(userVersion, SqliteDatabase.currentSchemaVersion);
          await relaunch.validateDatabaseSchema();
          final labels = await relaunch.select(relaunch.labels).get();
          expect(labels, hasLength(_labelCount));
          await relaunch.close();
        }
      });
    }
  }
}

QueryExecutor _connection(File file, {bool background = false}) {
  void setup(dynamic database) {
    database.execute('PRAGMA busy_timeout = 2000;');
    database.execute('PRAGMA journal_mode = WAL;');
  }

  return background
      ? NativeDatabase.createInBackground(file, setup: setup)
      : NativeDatabase(file, setup: setup);
}

Future<void> _openIgnoringFailure(QueryExecutor connection) async {
  final db = SqliteDatabase(connection);
  try {
    await db.customSelect('SELECT 1').get();
  } catch (_) {
    // A racing connection may fail (database is locked, or a step that the
    // other connection finished first); only the next launch matters.
  } finally {
    await db.close();
  }
}

void _seedLabels(File file, int version) {
  final reference = version < 12 ? 'ref' : 'reference';
  final db = sqlite3.open(file.path);
  try {
    for (var i = 0; i < _labelCount; i++) {
      db.execute(
        'INSERT INTO labels (label, $reference, type, origin) '
        "VALUES ('label $i', 'txid$i', 'tx', 'wallet')",
      );
    }
  } finally {
    db.dispose();
  }
}
