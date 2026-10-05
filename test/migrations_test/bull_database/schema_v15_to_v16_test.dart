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

  test('v15 to v16 drops the price history and keeps the settings', () async {
    final schema = await verifier.schemaAt(15);
    final oldDb = v15.DatabaseAtV15(schema.newConnection());
    await oldDb
        .into(oldDb.settings)
        .insert(
          v15.SettingsCompanion.insert(
            environment: 'mainnet',
            bitcoinUnit: 'sats',
            language: 'en',
            currency: 'CAD',
            hideAmounts: 0,
            isSuperuser: 0,
          ),
        );
    await oldDb
        .into(oldDb.prices)
        .insert(
          v15.PricesCompanion.insert(
            fromCurrency: 'BTC',
            toCurrency: 'CAD',
            interval: 'day',
            createdAt: '2026-11-01T00:00:00.000Z',
            indexPrice: const Value(108945.85),
          ),
        );
    await oldDb.close();

    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 16);
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row.read<String>('name'))
        .get();
    expect(tables, isNot(contains('prices')));
    await db.close();

    final migratedDb = v16.DatabaseAtV16(schema.newConnection());
    final settings = await migratedDb.select(migratedDb.settings).get();
    expect(settings.single.currency, 'CAD');
    await migratedDb.close();
  });

  test(
    'v15 to v16 keeps certificate validation for existing servers',
    () async {
      final schema = await verifier.schemaAt(15);
      final oldDb = v15.DatabaseAtV15(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.mempoolServers, [
          v15.MempoolServersCompanion.insert(
            url: 'mempool.local',
            isTestnet: 1,
            isLiquid: 0,
            isCustom: 1,
            enableSsl: const Value(1),
          ),
          v15.MempoolServersCompanion.insert(
            url: 'mempool.bullbitcoin.com',
            isTestnet: 0,
            isLiquid: 0,
            isCustom: 0,
            enableSsl: const Value(1),
          ),
        ]);
      });
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 16);

      final servers = await db.select(db.mempoolServers).get();
      expect(servers, hasLength(2));
      expect(servers.every((server) => server.validateDomain), isTrue);
      expect(servers.every((server) => server.enableSsl), isTrue);
      final custom = servers.singleWhere((server) => server.isCustom);
      expect(custom.url, 'mempool.local');
      expect(custom.isTestnet, isTrue);
      expect(custom.isLiquid, isFalse);
      final defaultServer = servers.singleWhere((server) => !server.isCustom);
      expect(defaultServer.url, 'mempool.bullbitcoin.com');
      expect(defaultServer.isTestnet, isFalse);
      expect(defaultServer.isLiquid, isFalse);
    },
  );
}
