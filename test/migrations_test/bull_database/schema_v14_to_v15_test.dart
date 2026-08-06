import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v14.dart' as v14;
import 'generated/schema_v15.dart' as v15;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v14 to v15: recoverbull telemetry baseline tables and settings '
      'flag', () {
    test('adds is_recoverbull_telemetry_enabled to settings, backfilling '
        'existing rows to false', () async {
      final schema = await verifier.schemaAt(14);

      final oldDb = v14.DatabaseAtV14(schema.newConnection());
      await oldDb
          .into(oldDb.settings)
          .insert(
            v14.SettingsCompanion.insert(
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

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 15);
      await db.close();

      final migratedDb = v15.DatabaseAtV15(schema.newConnection());
      final settings = await migratedDb.select(migratedDb.settings).get();
      expect(settings, hasLength(1));
      expect(settings.single.isRecoverbullTelemetryEnabled, 0);
      await migratedDb.close();
    });

    test('creates recoverbull_telemetry_server and '
        'recoverbull_telemetry_backup (empty by default) and they accept '
        'rows', () async {
      final schema = await verifier.schemaAt(14);

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 15);
      await db.close();

      final migratedDb = v15.DatabaseAtV15(schema.newConnection());

      // Newly created tables start empty.
      expect(
        await migratedDb.select(migratedDb.recoverbullTelemetryServer).get(),
        isEmpty,
      );
      expect(
        await migratedDb.select(migratedDb.recoverbullTelemetryBackup).get(),
        isEmpty,
      );

      // And they are writable/readable.
      await migratedDb
          .into(migratedDb.recoverbullTelemetryServer)
          .insert(
            v15.RecoverbullTelemetryServerCompanion.insert(
              serverUrl: 'http://example.onion',
              lastEtag: const Value('etag-1'),
              lastSuccessfulCheckAt: const Value(1750000000),
              collectionStartedAt: const Value(1749990000),
            ),
          );
      await migratedDb
          .into(migratedDb.recoverbullTelemetryBackup)
          .insert(
            v15.RecoverbullTelemetryBackupCompanion.insert(
              serverUrl: 'http://example.onion',
              backupIdHash: 'a' * 64,
              expectedTotalAttempts: const Value(2),
              currentWindowStartedAt: const Value(1750000000),
            ),
          );

      final serverRows = await migratedDb
          .select(migratedDb.recoverbullTelemetryServer)
          .get();
      expect(serverRows, hasLength(1));
      expect(serverRows.single.lastEtag, 'etag-1');
      expect(serverRows.single.consecutiveFailures, 0);

      final backupRows = await migratedDb
          .select(migratedDb.recoverbullTelemetryBackup)
          .get();
      expect(backupRows, hasLength(1));
      expect(backupRows.single.expectedTotalAttempts, 2);
      expect(backupRows.single.currentWindowStartedAt, 1750000000);

      await migratedDb.close();
    });
  });
}
