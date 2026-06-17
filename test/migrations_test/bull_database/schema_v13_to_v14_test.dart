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

  group('v13 to v14: frozen_utxos table (issue #760)', () {
    test('migration is additive — existing data intact, FrozenUtxos present',
        () async {
      final schema = await verifier.schemaAt(13);

      // Seed a v13 row that must survive the additive migration untouched.
      final oldDb = v13.DatabaseAtV13(schema.newConnection());
      await oldDb.into(oldDb.settings).insert(
            v13.SettingsCompanion.insert(
              environment: 'mainnet',
              bitcoinUnit: 'btc',
              language: 'en',
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

      // Pre-existing data is preserved.
      final settings = await migratedDb.select(migratedDb.settings).get();
      expect(settings, hasLength(1));
      expect(settings.single.environment, 'mainnet');
      expect(settings.single.currency, 'USD');

      // The new FrozenUtxos table exists and is writable, defaulting origin.
      await migratedDb.into(migratedDb.frozenUtxos).insert(
            v14.FrozenUtxosCompanion.insert(
              walletId: 'w1',
              txId: 'tx1',
              vout: 0,
            ),
          );
      final frozen = await migratedDb.select(migratedDb.frozenUtxos).get();
      expect(frozen, hasLength(1));
      expect(frozen.single.walletId, 'w1');
      expect(frozen.single.origin, 'user');

      await migratedDb.close();
    });
  });
}
