import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v13.dart' as v13;
import 'generated/schema_v14.dart' as v14;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v13 to v14: settings hide_exchange_features column', () {
    test('existing settings row gets hide_exchange_features defaulting to 0', () async {
      final schema = await verifier.schemaAt(13);

      final oldDb = v13.DatabaseAtV13(schema.newConnection());
      await oldDb
          .into(oldDb.settings)
          .insert(
            v13.SettingsCompanion.insert(
              id: const Value(1),
              environment: 'mainnet',
              bitcoinUnit: 'sats',
              language: 'unitedStatesEnglish',
              currency: 'USD',
              hideAmounts: 0,
              isSuperuser: 0,
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 14);
      await db.close();

      final migratedDb = v14.DatabaseAtV14(schema.newConnection());
      final settings = await migratedDb.select(migratedDb.settings).get();

      expect(settings, hasLength(1));
      expect(settings.single.id, 1);
      // Defaults to 0 (false) so existing installs keep exchange features shown.
      expect(settings.single.hideExchangeFeatures, 0);

      await migratedDb.close();
    });

    test('hide_exchange_features is writable after migration', () async {
      final schema = await verifier.schemaAt(13);

      final oldDb = v13.DatabaseAtV13(schema.newConnection());
      await oldDb
          .into(oldDb.settings)
          .insert(
            v13.SettingsCompanion.insert(
              id: const Value(1),
              environment: 'mainnet',
              bitcoinUnit: 'sats',
              language: 'unitedStatesEnglish',
              currency: 'USD',
              hideAmounts: 0,
              isSuperuser: 0,
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 14);
      await db.close();

      final migratedDb = v14.DatabaseAtV14(schema.newConnection());
      await (migratedDb.update(migratedDb.settings)
            ..where((s) => s.id.equals(1)))
          .write(const v14.SettingsCompanion(hideExchangeFeatures: Value(1)));

      final updated = await migratedDb.select(migratedDb.settings).get();
      expect(updated.single.hideExchangeFeatures, 1);

      await migratedDb.close();
    });
  });
}
