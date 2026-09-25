import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v15.dart' as v15;
import 'generated/schema_v16.dart' as v16;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v15 to v16 adds send_timestamps and preserves existing rows', () async {
    final schema = await verifier.schemaAt(15);
    final oldDb = v15.DatabaseAtV15(schema.newConnection());
    await oldDb
        .into(oldDb.settings)
        .insert(
          v15.SettingsCompanion.insert(
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
    await verifier.migrateAndValidate(db, 16);
    await db.close();

    final migratedDb = v16.DatabaseAtV16(schema.newConnection());

    // The migration only creates a table, so nothing already stored may move.
    final settings = await migratedDb.select(migratedDb.settings).get();
    expect(settings, hasLength(1));
    expect(settings.single.environment, 'testnet');
    expect(settings.single.currency, 'USD');

    // There is nothing to backfill: the broadcast moment of a transaction sent
    // before this release was never captured and cannot be recovered.
    final sendTimestamps = await migratedDb
        .select(migratedDb.sendTimestamps)
        .get();
    expect(sendTimestamps, isEmpty);

    await migratedDb.close();
  });

  test('v16 send_timestamps stores a broadcast time keyed by txid', () async {
    final schema = await verifier.schemaAt(15);
    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 16);
    await db.close();

    final migratedDb = v16.DatabaseAtV16(schema.newConnection());
    await migratedDb
        .into(migratedDb.sendTimestamps)
        .insert(
          v16.SendTimestampsCompanion.insert(
            txid: 'a' * 64,
            sentAtSecs: 1756819200,
          ),
        );

    final rows = await migratedDb.select(migratedDb.sendTimestamps).get();
    expect(rows, hasLength(1));
    expect(rows.single.txid, 'a' * 64);
    expect(rows.single.sentAtSecs, 1756819200);

    await migratedDb.close();
  });
}
