import 'dart:io';

import 'package:bb_mobile/core/storage/migrations/migrations.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
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
import 'generated/schema_v15.dart' as v15;
import 'generated/schema_v16.dart' as v16;
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
  15: v15.DatabaseAtV15.new,
  16: v16.DatabaseAtV16.new,
};

const _labelCount = 3;

/// The migration steps as every release before this one ran them: no
/// transaction around a step, so a crash can leave one half-applied. On a
/// first run these steps issue the same writes, in the same order, as the
/// released ones (only `INSERT` became `INSERT OR IGNORE` for the 1→2 and
/// 9→10 seeds), so stopping them part-way reproduces what a crash left on
/// devices running an older release.
class _ReleasedMigrationOrder extends SqliteDatabase {
  _ReleasedMigrationOrder(super.executor);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: Schema0To1.onCreate,
    onUpgrade: stepByStep(
      from1To2: Schema1To2.migrate,
      from2To3: Schema2To3.migrate,
      from3To4: Schema3To4.migrate,
      from4To5: Schema4To5.migrate,
      from5To6: Schema5To6.migrate,
      from6To7: Schema6To7.migrate,
      from7To8: Schema7To8.migrate,
      from8To9: Schema8To9.migrate,
      from9To10: Schema9To10.migrate,
      from10To11: Schema10To11.migrate,
      from11To12: Schema11To12.migrate,
      from12To13: Schema12To13.migrate,
      from13To14: Schema13To14.migrate,
      from14To15: Schema14To15.migrate,
      from15To16: Schema15To16.migrate,
    ),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // The app can be killed at any point while it upgrades the database. Every
  // commit is a point where the process can die, so each test stops the
  // upgrade after every possible number of commits, then relaunches with the
  // current code. The relaunch must reach the current schema, validate, and
  // keep every label that survived the crash.
  group('killed after any commit while upgrading on an older release', () {
    for (final MapEntry(key: version, value: fixture) in _fixtures.entries) {
      test('from schema $version, the next launch recovers', () async {
        await _everyCrashPoint(
          seed: (file) => _seedFixture(file, version, fixture),
          crashingOpen: (executor) => _ReleasedMigrationOrder(executor),
        );
      });
    }
  });

  // Each step commits as one transaction, so on this release a crash can
  // never lose a label.
  group('killed after any commit while upgrading on this release', () {
    for (final MapEntry(key: version, value: fixture) in _fixtures.entries) {
      test('from schema $version, the next launch recovers with every '
          'label', () async {
        await _everyCrashPoint(
          seed: (file) => _seedFixture(file, version, fixture),
          crashingOpen: SqliteDatabase.new,
          everyLabelSurvives: true,
        );
      });
    }
  });

  // An older release killed during its first launch left its own schema's
  // tables, whole or in part, with user_version still 0.
  group('a first launch an older release did not finish', () {
    for (final MapEntry(key: version, value: fixture) in _fixtures.entries) {
      for (final partial in [false, true]) {
        final left = partial ? 'half of its tables' : 'all its tables';
        test('with $left from schema $version, the next launch is a clean '
            'install', () async {
          final dir = await Directory.systemTemp.createTemp('bull_unfinished');
          addTearDown(() => dir.delete(recursive: true));
          final file = File('${dir.path}/${SqliteDatabase.name}.sqlite');
          final seeded = fixture(NativeDatabase(file));
          await seeded.customSelect('SELECT 1').get();
          await seeded.close();
          _leaveUnfinished(file, dropHalf: partial);

          final relaunch = SqliteDatabase(NativeDatabase(file));
          await relaunch.customSelect('SELECT 1').get();
          await relaunch.validateDatabaseSchema();
          await relaunch.close();

          expect(_dump(file), _dump(await _cleanInstall(dir)));
        });
      }
    }
  });

  test('a first launch leftover holding user data is refused and left '
      'untouched', () async {
    final dir = await Directory.systemTemp.createTemp('bull_unfinished');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/${SqliteDatabase.name}.sqlite');
    await _seedFixture(file, 14, v14.DatabaseAtV14.new);
    _leaveUnfinished(file, dropHalf: false);
    final before = _dump(file);

    final db = SqliteDatabase(NativeDatabase(file));
    await expectLater(db.customSelect('SELECT 1').get(), throwsA(anything));
    await db.close();

    expect(_dump(file), before);
    expect(_labelRows(file), _labelCount);
  });

  test('killed after any commit during the first launch of a fresh install '
      'on an older release, the next launch recovers', () async {
    await _everyCrashPoint(
      seed: (_) async {},
      crashingOpen: (executor) => _ReleasedMigrationOrder(executor),
      expectLabels: false,
    );
  });

  test('killed after any commit during the first launch of a fresh install, '
      'the next launch recovers', () async {
    await _everyCrashPoint(
      seed: (_) async {},
      crashingOpen: SqliteDatabase.new,
      expectLabels: false,
    );
  });
}

/// Seeds a database, opens it with [crashingOpen] on a connection that
/// refuses every commit after the first `allowed`, for every `allowed` until
/// the open completes, and checks a normal relaunch after each crash.
Future<void> _everyCrashPoint({
  required Future<void> Function(File file) seed,
  required SqliteDatabase Function(QueryExecutor executor) crashingOpen,
  bool expectLabels = true,
  bool everyLabelSurvives = false,
}) async {
  for (var allowed = 0; ; allowed++) {
    final dir = await Directory.systemTemp.createTemp('bull_crash');
    try {
      final file = File('${dir.path}/${SqliteDatabase.name}.sqlite');
      await seed(file);

      var remaining = allowed;
      final crashing = crashingOpen(
        NativeDatabase(
          file,
          setup: (database) {
            database.commitFilter = () => remaining-- > 0;
          },
        ),
      );
      var completed = true;
      try {
        await crashing.customSelect('SELECT 1').get();
      } catch (_) {
        completed = false;
      } finally {
        await crashing.close();
      }

      final survivingLabels = _labelRows(file);
      final relaunch = SqliteDatabase(NativeDatabase(file));
      try {
        final userVersion = await relaunch
            .customSelect('PRAGMA user_version')
            .map((row) => row.read<int>('user_version'))
            .getSingle();
        expect(
          userVersion,
          SqliteDatabase.currentSchemaVersion,
          reason: 'crash after $allowed commits',
        );
        await relaunch.validateDatabaseSchema();
        final labels = await relaunch.select(relaunch.labels).get();
        expect(
          labels,
          hasLength(survivingLabels),
          reason: 'crash after $allowed commits',
        );
        if (expectLabels && (completed || everyLabelSurvives)) {
          expect(
            labels,
            hasLength(_labelCount),
            reason: 'crash after $allowed commits',
          );
        }
      } finally {
        await relaunch.close();
      }

      if (completed) return;
    } finally {
      await dir.delete(recursive: true);
    }
  }
}

Future<void> _seedFixture(
  File file,
  int version,
  GeneratedDatabase Function(QueryExecutor) fixture,
) async {
  final seeded = fixture(NativeDatabase(file));
  await seeded.customSelect('SELECT 1').get();
  final reference = version < 12 ? 'ref' : 'reference';
  for (var i = 0; i < _labelCount; i++) {
    await seeded.customStatement(
      'INSERT INTO labels (label, $reference, type, origin) '
      "VALUES ('label $i', 'txid$i', 'tx', 'wallet')",
    );
  }
  await seeded.close();
}

/// Label rows on disk in whichever shape the crash left the table, or 0 when
/// it has no labels table.
int _labelRows(File file) {
  final db = sqlite3.open(file.path);
  try {
    final hasTable = db
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'labels'",
        )
        .isNotEmpty;
    if (!hasTable) return 0;
    return db.select('SELECT COUNT(*) AS c FROM labels').single['c'] as int;
  } finally {
    db.dispose();
  }
}

/// Resets [file] to user_version 0, as a killed first launch leaves it, and
/// optionally drops the second half of its tables.
void _leaveUnfinished(File file, {required bool dropHalf}) {
  final db = sqlite3.open(file.path);
  try {
    if (dropHalf) {
      final tables = db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT "
            "LIKE 'sqlite_%' ORDER BY rowid",
          )
          .map((row) => row['name'] as String)
          .toList();
      for (final table in tables.skip(tables.length ~/ 2)) {
        db.execute('DROP TABLE "$table"');
      }
    }
    db.userVersion = 0;
  } finally {
    db.dispose();
  }
}

Future<File> _cleanInstall(Directory dir) async {
  final file = File('${dir.path}/clean.sqlite');
  final db = SqliteDatabase(NativeDatabase(file));
  await db.customSelect('SELECT 1').get();
  await db.close();
  return file;
}

/// user_version, every schema object, every row, and the autoincrement
/// counters, order-independent.
Map<String, List<String>> _dump(File file) {
  final db = sqlite3.open(file.path);
  try {
    final dump = <String, List<String>>{
      'user_version': ['${db.userVersion}'],
      'sqlite_master': db
          .select(
            'SELECT type, name, tbl_name, sql FROM sqlite_master '
            "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
          )
          .map((row) => row.toString())
          .toList(),
    };
    final tables = db
        .select(
          "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
        )
        .map((row) => row['name'] as String);
    for (final table in tables) {
      dump[table] =
          db
              .select('SELECT * FROM "$table"')
              .map((row) => row.toString())
              .toList()
            ..sort();
    }
    return dump;
  } finally {
    db.dispose();
  }
}
