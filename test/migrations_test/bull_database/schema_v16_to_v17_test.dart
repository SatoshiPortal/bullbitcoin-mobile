import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v16.dart' as v16;

void main() {
  late SchemaVerifier verifier;
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<void> insertVault(v16.DatabaseAtV16 db) async {
    await db.customStatement('''
      INSERT INTO wallet_metadatas
        (id, network, public_descriptor, is_encrypted_vault_tested,
         is_physical_backup_tested, is_default, label)
      VALUES ('vault', 'bitcoinMainnet', 'public fixture descriptor', 1, 1, 0, 'My vault')
    ''');
    await db.customStatement('''
      INSERT INTO bull_vault_records
        (wallet_id, lineage_id, vault_generation, recovery_package, status,
         hardware_setup_complete, hardware_setup_deferred,
         completed_hardware_signer_ids_json, recovery_package_confirmed,
         mobile_backup_deferred, created_at)
      VALUES ('vault', 'lineage', 0, 'public fixture package', 'active',
              1, 0, '[]', 1, 0, '2026-09-18T00:00:00.000Z')
    ''');
  }

  test(
    'v17 adds backup state and empty local receipts without changing v16 facts',
    () async {
      final schema = await verifier.schemaAt(16);
      final old = v16.DatabaseAtV16(schema.newConnection());
      await insertVault(old);
      await old.close();
      final db = SqliteDatabase(schema.newConnection());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        17,
      );
      final vault = await db
          .customSelect('SELECT * FROM bull_vault_records')
          .getSingle();
      expect(vault.read<String>('recovery_package'), 'public fixture package');
      expect(vault.read<String>('status'), 'active');
      expect(vault.data['descriptor_tested_at'], isNull);
      expect(vault.data['server_tested_at'], isNull);
      expect(
        vault.data.keys,
        containsAll(['descriptor_tested_at', 'server_tested_at']),
      );
      final wallet = await db
          .customSelect('SELECT * FROM wallet_metadatas')
          .getSingle();
      expect(wallet.read<String>('label'), 'My vault');
      expect(
        wallet.read<String>('public_descriptor'),
        'public fixture descriptor',
      );
      for (final table in [
        'wallet_backup_states',
        'wallet_backup_controls',
        'keychain_nostr_keys',
      ]) {
        expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
      }
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('a failed v17 migration is atomic and can be retried', () async {
    final schema = await verifier.schemaAt(16);
    final old = v16.DatabaseAtV16(schema.newConnection());
    await insertVault(old);
    await old.customStatement(
      'ALTER TABLE bull_vault_records ADD COLUMN server_tested_at TEXT',
    );
    await old.close();
    final failed = SqliteDatabase(schema.newConnection());
    await expectLater(failed.customSelect('SELECT 1').get(), throwsA(anything));
    await failed.close();
    final rolledBack = v16.DatabaseAtV16(schema.newConnection());
    final columns = await rolledBack
        .customSelect('PRAGMA table_info(bull_vault_records)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      isNot(contains('descriptor_tested_at')),
    );
    expect(
      (await rolledBack.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      16,
    );
    expect(
      await rolledBack
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name IN ('wallet_backup_states', 'wallet_backup_controls', 'keychain_nostr_keys')",
          )
          .get(),
      isEmpty,
    );
    await rolledBack.customStatement(
      'ALTER TABLE bull_vault_records DROP COLUMN server_tested_at',
    );
    await rolledBack.close();
    final retry = SqliteDatabase(schema.newConnection());
    addTearDown(retry.close);
    await retry.customSelect('SELECT 1 FROM keychain_nostr_keys').get();
    expect(
      (await retry.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      17,
    );
  });
}
