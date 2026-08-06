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
    // Brute-force telemetry is added in the same step and defaults to
    // disabled (0): the feature rolls out only once the server contract and
    // the pinned client are confirmed in production.
    expect(settings.single.isRecoverbullTelemetryEnabled, 0);
    await migratedDb.close();
  });

  test('v14 to v15 creates the recoverbull telemetry tables, empty and '
      'writable', () async {
    final schema = await verifier.schemaAt(14);

    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 15);
    await db.close();

    final migratedDb = v15.DatabaseAtV15(schema.newConnection());

    // Newly created tables start empty: existing installs simply have no
    // telemetry baseline yet.
    expect(
      await migratedDb.select(migratedDb.recoverbullTelemetryServer).get(),
      isEmpty,
    );
    expect(
      await migratedDb.select(migratedDb.recoverbullTelemetryBackup).get(),
      isEmpty,
    );

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
}
