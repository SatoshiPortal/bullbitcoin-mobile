import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v13.dart' as v13;
import 'generated/schema_v14.dart' as v14;
import 'generated/schema_v15.dart' as v15;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v14 to v15 adds Tor transport and screen-capture settings with '
      'defaults', () async {
    final schema = await verifier.schemaAt(14);
    final oldDb = v14.DatabaseAtV14(schema.newConnection());
    await oldDb
        .into(oldDb.settings)
        .insert(
          v14.SettingsCompanion.insert(
            environment: 'testnet',
            bitcoinUnit: 'sats',
            language: 'en',
            currency: 'USD',
            hideAmounts: 0,
            isSuperuser: 0,
          ),
        );
    await oldDb.close();

    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 15);
    await db.close();

    final migratedDb = v15.DatabaseAtV15(schema.newConnection());
    final settings = await migratedDb.select(migratedDb.settings).get();
    expect(settings, hasLength(1));
    expect(settings.single.environment, 'testnet');
    expect(settings.single.torTransportMode, 'automatic');
    expect(settings.single.lastSuccessfulTorTransport, isNull);
    // Screen-capture protection is added in this step and defaults to enabled
    // (1) so existing installs keep protection until the user opts out.
    expect(settings.single.screenCaptureProtectionEnabled, 1);
    await migratedDb.close();
  });

  test(
    'v14 to v15 tolerates tor columns already present (idempotency guard)',
    () async {
      final schema = await verifier.schemaAt(14);

      // Simulate a dev device that received the tor columns from develop's
      // earlier, broken 13->14 build: add them onto the released v14 settings
      // table before upgrading.
      final seeded = v14.DatabaseAtV14(schema.newConnection());
      await seeded.customStatement(
        "ALTER TABLE settings ADD COLUMN tor_transport_mode TEXT NOT NULL "
        "DEFAULT 'automatic'",
      );
      await seeded.customStatement(
        'ALTER TABLE settings ADD COLUMN last_successful_tor_transport TEXT',
      );
      await seeded.close();

      // Opening the app database runs the 14->15 migration. The _addColumnIfNot
      // Exists guard must skip the duplicate tor adds instead of throwing, and
      // still add the new screen-capture column.
      final db = SqliteDatabase(schema.newConnection());
      final columns = await db
          .customSelect("SELECT name FROM pragma_table_info('settings')")
          .map((row) => row.read<String>('name'))
          .get();
      expect(columns, contains('tor_transport_mode'));
      expect(columns, contains('last_successful_tor_transport'));
      expect(columns, contains('screen_capture_protection_enabled'));
      await db.close();
    },
  );

  test('v14 to v15 tolerates ALL THREE v15 columns already present '
      '(6.13.2 completed, then downgraded to a schema-14 build)', () async {
    final schema = await verifier.schemaAt(14);

    // Exact field case: a device ran a schema-15 build (6.13.2) whose 14->15
    // added all three columns, then a schema-14 build (6.13.3) brought the
    // recorded version back to 14 while the columns physically remained.
    final seeded = v14.DatabaseAtV14(schema.newConnection());
    await seeded.customStatement(
      "ALTER TABLE settings ADD COLUMN tor_transport_mode TEXT NOT NULL "
      "DEFAULT 'automatic'",
    );
    await seeded.customStatement(
      'ALTER TABLE settings ADD COLUMN last_successful_tor_transport TEXT',
    );
    await seeded.customStatement(
      'ALTER TABLE settings ADD COLUMN screen_capture_protection_enabled '
      'INTEGER NOT NULL DEFAULT 1',
    );
    await seeded.close();

    // Opening runs 14->15; the guard must skip every already-present column
    // instead of throwing duplicate column. Reaching these queries at all
    // proves the migration did not throw.
    final db = SqliteDatabase(schema.newConnection());
    final columns = await db
        .customSelect("SELECT name FROM pragma_table_info('settings')")
        .map((row) => row.read<String>('name'))
        .get();
    expect(columns, contains('tor_transport_mode'));
    expect(columns, contains('last_successful_tor_transport'));
    expect(columns, contains('screen_capture_protection_enabled'));

    final userVersion = await db
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    expect(userVersion, 15);
    await db.close();
  });

  test(
    'v13 to v15 survives two connections migrating concurrently '
    '(foreground app + background task on first launch after update)',
    () async {
      // drift runs migrations without a transaction and writes user_version
      // after each step, so the slower connection overwrites 15 with 14 and
      // then re-runs 14->15 over columns the faster one already added. Without
      // the 14->15 guard this left the field device permanently at 14.
      for (var run = 0; run < 10; run++) {
        final dir = await Directory.systemTemp.createTemp(
          'bull_migration_race',
        );
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
        expect(userVersion, 15);
        await relaunch.close();
      }
    },
  );
}
