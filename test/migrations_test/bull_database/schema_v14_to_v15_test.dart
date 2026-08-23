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

  test('v14 to v15 adds settings with secure defaults', () async {
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
    await oldDb
        .into(oldDb.mempoolServers)
        .insert(
          v14.MempoolServersCompanion.insert(
            url: 'mempool.local',
            isTestnet: 0,
            isLiquid: 0,
            isCustom: 1,
            enableSsl: const Value(1),
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

    final mempoolServers = await migratedDb
        .select(migratedDb.mempoolServers)
        .get();
    expect(mempoolServers, hasLength(1));
    expect(mempoolServers.single.url, 'mempool.local');
    expect(mempoolServers.single.validateDomain, 1);
    await migratedDb.close();
  });
}
