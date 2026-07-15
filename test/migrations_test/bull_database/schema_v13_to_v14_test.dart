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

  group('v13 to v14: settings payjoin_min_amount_sat and '
      'payjoin_expire_after_sec columns', () {
    test('adds payjoin_min_amount_sat and payjoin_expire_after_sec, '
        'backfilling existing rows to 10000 and 60', () async {
      final schema = await verifier.schemaAt(13);

      // Seed a v13 settings row (no payjoin_min_amount_sat or
      // payjoin_expire_after_sec column yet).
      final oldDb = v13.DatabaseAtV13(schema.newConnection());
      await oldDb
          .into(oldDb.settings)
          .insert(
            v13.SettingsCompanion.insert(
              id: const Value(1),
              environment: 'mainnet',
              bitcoinUnit: 'sats',
              language: 'en',
              currency: 'USD',
              hideAmounts: 0,
              isSuperuser: 0,
            ),
          );
      await oldDb.close();

      // Migrate to v14 and validate the schema matches the generated shape.
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 14);
      await db.close();

      // The existing row must be backfilled to the DB defaults (10000,
      // 60).
      final migratedDb = v14.DatabaseAtV14(schema.newConnection());
      final settings = await migratedDb.select(migratedDb.settings).get();
      expect(settings, hasLength(1));
      expect(settings.single.payjoinMinAmountSat, 10000);
      expect(settings.single.payjoinExpireAfterSec, 60);
      await migratedDb.close();
    });
  });
}
