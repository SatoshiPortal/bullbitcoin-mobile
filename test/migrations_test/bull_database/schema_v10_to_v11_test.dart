import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v10.dart' as v10;
import 'generated/schema_v11.dart' as v11;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v10 to v11: auto_swap triggerBalanceSats', () {
    test('with existing auto_swap data', () async {
      final schema = await verifier.schemaAt(10);

      final oldDb = v10.DatabaseAtV10(schema.newConnection());

      await oldDb
          .into(oldDb.autoSwap)
          .insert(
            v10.AutoSwapCompanion.insert(
              enabled: const Value(true),
              balanceThresholdSats: 1000000,
              feeThresholdPercent: 0.5,
            ),
          );

      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 11);
      await db.close();

      final migratedDb = v11.DatabaseAtV11(schema.newConnection());

      final allAutoSwaps = await migratedDb.select(migratedDb.autoSwap).get();
      expect(allAutoSwaps.length, 1);

      final autoSwap = allAutoSwaps.first;
      expect(autoSwap.enabled, 1);
      expect(autoSwap.balanceThresholdSats, 1000000);
      expect(autoSwap.triggerBalanceSats, 2000000);
      expect(autoSwap.feeThresholdPercent, 0.5);
      expect(autoSwap.showWarning, 1);

      await migratedDb.close();
    });

    test('with multiple auto_swap records', () async {
      final schema = await verifier.schemaAt(10);

      final oldDb = v10.DatabaseAtV10(schema.newConnection());

      await oldDb
          .into(oldDb.autoSwap)
          .insert(
            v10.AutoSwapCompanion.insert(
              enabled: const Value(true),
              balanceThresholdSats: 500000,
              feeThresholdPercent: 0.3,
            ),
          );

      await oldDb
          .into(oldDb.autoSwap)
          .insert(
            v10.AutoSwapCompanion.insert(
              enabled: const Value(false),
              balanceThresholdSats: 2000000,
              feeThresholdPercent: 1.0,
            ),
          );

      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 11);
      await db.close();

      final migratedDb = v11.DatabaseAtV11(schema.newConnection());

      final allAutoSwaps = await migratedDb.select(migratedDb.autoSwap).get();
      expect(allAutoSwaps.length, 2);

      final autoSwap1 = allAutoSwaps[0];
      expect(autoSwap1.balanceThresholdSats, 500000);
      expect(autoSwap1.triggerBalanceSats, 1000000);

      final autoSwap2 = allAutoSwaps[1];
      expect(autoSwap2.balanceThresholdSats, 2000000);
      expect(autoSwap2.triggerBalanceSats, 4000000);

      await migratedDb.close();
    });

    test('with empty auto_swap table', () async {
      final schema = await verifier.schemaAt(10);

      final oldDb = v10.DatabaseAtV10(schema.newConnection());
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 11);
      await db.close();

      final migratedDb = v11.DatabaseAtV11(schema.newConnection());
      final allAutoSwaps = await migratedDb.select(migratedDb.autoSwap).get();
      expect(allAutoSwaps.length, 0);
      await migratedDb.close();
    });
  });

  group('v10 to v11: prices table', () {
    test('prices table created', () async {
      final schema = await verifier.schemaAt(10);

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 11);
      await db.close();

      final migratedDb = v11.DatabaseAtV11(schema.newConnection());

      expect(await migratedDb.select(migratedDb.prices).get(), []);
      await migratedDb.close();
    });
  });

  group('v10 to v11: settings themeMode', () {
    test('themeMode column added with default', () async {
      final schema = await verifier.schemaAt(10);

      final oldDb = v10.DatabaseAtV10(schema.newConnection());
      await oldDb
          .into(oldDb.settings)
          .insert(
            v10.SettingsCompanion.insert(
              environment: 'mainnet',
              bitcoinUnit: 'sats',
              language: 'en',
              currency: 'USD',
              hideAmounts: false,
              isSuperuser: false,
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 11);
      await db.close();

      final migratedDb = v11.DatabaseAtV11(schema.newConnection());
      final settings = await migratedDb.select(migratedDb.settings).getSingle();
      expect(settings.themeMode, 'system');
      await migratedDb.close();
    });
  });

  group('v10 to v11: mempool tables', () {
    test('mempool tables created and seeded', () async {
      final schema = await verifier.schemaAt(10);

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 11);
      await db.close();

      final migratedDb = v11.DatabaseAtV11(schema.newConnection());

      final mempoolServers = await migratedDb
          .select(migratedDb.mempoolServers)
          .get();
      expect(mempoolServers.length, 4);

      final mempoolSettings = await migratedDb
          .select(migratedDb.mempoolSettings)
          .get();
      expect(mempoolSettings.length, 4);

      await migratedDb.close();
    });
  });
}
