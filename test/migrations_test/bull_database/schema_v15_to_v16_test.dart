import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v15.dart' as v15;
import 'generated/schema_v16.dart' as v16;
import 'package:drift/drift.dart' hide isNotNull, isNull;

void main() {
  test('network backfill preserves identities and Electrum configuration', () async {
    final schema = await SchemaVerifier(GeneratedHelper()).schemaAt(15);
    final old = v15.DatabaseAtV15(schema.newConnection());
    const networks = {
      'wpkh([aabbccdd/84h/0h/0h])': 'bitcoinMainnet',
      'wpkh([aabbccdd/84h/1h/0h])': 'bitcoinTestnet',
      'elwpkh([aabbccdd/84h/1776h/0h])': 'liquidMainnet',
      'elwpkh([aabbccdd/84h/1h/0h])': 'liquidTestnet',
      'unrecognized-origin': 'unresolved',
    };
    for (final id in networks.keys) {
      await old.customStatement(
        '''
        INSERT INTO wallet_metadatas
        (id, master_fingerprint, xpub_fingerprint, is_encrypted_vault_tested,
         is_physical_backup_tested, xpub, external_public_descriptor,
         internal_public_descriptor, signer, is_default)
        VALUES (?, 'aabbccdd', 'aabbccdd', 0, 0, 'public', 'public', 'public', 'local', 0)
      ''',
        [id],
      );
    }
    await old.customStatement(
      "INSERT INTO electrum_servers (url, is_testnet, is_liquid, priority, is_custom) VALUES ('tcp://local.example:50000', 1, 0, 7, 1)",
    );
    await old.close();
    final db = SqliteDatabase(schema.newConnection());
    addTearDown(db.close);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(db, 16);
    final rows = await db
        .customSelect('SELECT id, network FROM wallet_metadatas')
        .get();
    expect({
      for (final row in rows)
        row.read<String>('id'): row.read<String>('network'),
    }, networks);
    final custom = await db
        .customSelect("SELECT * FROM electrum_servers WHERE is_custom = 1")
        .getSingle();
    expect(custom.read<String>('network'), 'bitcoinTestnet');
    expect(custom.read<int>('priority'), 7);
    // Identical endpoints on different networks no longer conflict.
    await db.customStatement(
      "INSERT INTO electrum_servers (url, network, priority, is_custom) VALUES ('tcp://local.example:50000', 'bitcoinRegtest', 2, 1)",
    );
    expect(
      await db
          .customSelect(
            "SELECT * FROM electrum_servers WHERE url = 'tcp://local.example:50000'",
          )
          .get(),
      hasLength(2),
    );
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name IN ('prices', 'transactions', 'labels', 'frozen_utxos', 'mempool_servers', 'mempool_settings')",
          )
          .get(),
      hasLength(5),
    );
  });
  test('v15 to v16 drops the price history and keeps the settings', () async {
    final schema = await SchemaVerifier(GeneratedHelper()).schemaAt(15);
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
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(db, 16);
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
}
