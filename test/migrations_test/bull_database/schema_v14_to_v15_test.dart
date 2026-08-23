import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v14.dart' as v14;
import 'generated/schema_v15.dart' as v15;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'v14 to v15 preserves wallets and adds the six locked capabilities',
    () async {
      final schema = await verifier.schemaAt(14);
      final oldDb = v14.DatabaseAtV14(schema.newConnection());
      await oldDb
          .into(oldDb.walletMetadatas)
          .insert(
            v14.WalletMetadatasCompanion.insert(
              id: 'wallet-1',
              masterFingerprint: 'aabbccdd',
              xpubFingerprint: '11223344',
              isEncryptedVaultTested: 0,
              isPhysicalBackupTested: 0,
              xpub: 'xpub',
              externalPublicDescriptor: 'external',
              internalPublicDescriptor: 'internal',
              signer: 'local',
              isDefault: 1,
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 15);
      await db.close();

      final migrated = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(migrated.close);
      await migrated.customStatement('PRAGMA foreign_keys = ON');
      final wallet = await migrated
          .select(migrated.walletMetadatas)
          .getSingle();
      expect(wallet.id, 'wallet-1');
      expect(wallet.hideOnHome, isNull);
      expect(wallet.autoSweepEnabled, isNull);
      await migrated
          .update(migrated.walletMetadatas)
          .write(
            const v15.WalletMetadatasCompanion(
              hideOnHome: Value(1),
              autoSweepEnabled: Value(0),
            ),
          );
      final updatedWallet = await migrated
          .select(migrated.walletMetadatas)
          .getSingle();
      expect(updatedWallet.hideOnHome, 1);
      expect(updatedWallet.autoSweepEnabled, 0);

      await migrated
          .into(migrated.keychainManifestEntries)
          .insert(
            v15.KeychainManifestEntriesCompanion.insert(
              entryId: 'entry-1',
              parentFingerprint: 'aabbccdd',
              bip85DerivationPath: "39'/0'/12'/100'",
              reservationId: 'btcpay_wallet_seed',
              entryType: 'walletSeed',
              ownerFeature: 'btcpay',
              bip85Application: 39,
              bip85Index: 100,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await migrated
          .into(migrated.keychainManifestWalletBindings)
          .insert(
            v15.KeychainManifestWalletBindingsCompanion.insert(
              walletId: 'wallet-1',
              entryId: 'entry-1',
              childSeedFingerprint: 'eeff0011',
              network: 'bitcoinMainnet',
              scriptType: 'bip84',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await migrated
          .into(migrated.keychainManifestNostrKeys)
          .insert(
            v15.KeychainManifestNostrKeysCompanion.insert(
              entryId: 'entry-1',
              publicKeyHex: '02',
              keyKind: 'xOnly',
              purpose: 'backup',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await migrated
          .into(migrated.walletBackupStates)
          .insert(v15.WalletBackupStatesCompanion.insert());

      expect(
        () => migrated.customStatement(
          "INSERT INTO keychain_manifest_entries "
          "SELECT 'entry-2', parent_fingerprint, bip85_derivation_path, "
          'reservation_id, entry_type, owner_feature, bip85_application, '
          'bip85_index, created_at, updated_at '
          "FROM keychain_manifest_entries WHERE entry_id = 'entry-1'",
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => migrated.customStatement(
          'INSERT INTO keychain_manifest_wallet_bindings '
          'SELECT * FROM keychain_manifest_wallet_bindings',
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => migrated.customStatement(
          'INSERT INTO keychain_manifest_nostr_keys '
          'SELECT * FROM keychain_manifest_nostr_keys',
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => migrated.customStatement(
          "INSERT INTO keychain_manifest_wallet_bindings "
          "SELECT 'wallet-2', 'missing-entry', child_seed_fingerprint, "
          'network, script_type, created_at, updated_at '
          'FROM keychain_manifest_wallet_bindings',
        ),
        throwsA(isA<SqliteException>()),
      );

      await migrated.customStatement(
        "UPDATE keychain_manifest_entries SET updated_at = 2 "
        "WHERE entry_id = 'entry-1'",
      );
      await migrated.customStatement(
        "UPDATE keychain_manifest_wallet_bindings SET network = "
        "'liquidMainnet' WHERE wallet_id = 'wallet-1'",
      );
      await migrated.customStatement(
        "UPDATE keychain_manifest_nostr_keys SET description = 'backup key' "
        "WHERE entry_id = 'entry-1'",
      );
      await migrated.customStatement(
        'UPDATE wallet_backup_states SET enabled = 1, '
        'recovery_blocked = 1 WHERE id = 1',
      );

      final entry = await migrated
          .select(migrated.keychainManifestEntries)
          .getSingle();
      final binding = await migrated
          .select(migrated.keychainManifestWalletBindings)
          .getSingle();
      final nostrKey = await migrated
          .select(migrated.keychainManifestNostrKeys)
          .getSingle();
      final backup = await migrated
          .select(migrated.walletBackupStates)
          .getSingle();
      expect(entry.updatedAt, 2);
      expect(binding.network, 'liquidMainnet');
      expect(nostrKey.description, 'backup key');
      expect(backup.enabled, 1);
      expect(backup.recoveryBlocked, 1);
    },
  );

  test('fresh schema creates only the final version-15 storage', () async {
    final db = SqliteDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('keychain_manifest_entries', "
          "'keychain_manifest_wallet_bindings', "
          "'keychain_manifest_nostr_keys', 'wallet_backup_states')",
        )
        .map((row) => row.read<String>('name'))
        .get();
    final walletColumns = await db
        .customSelect('PRAGMA table_info(wallet_metadatas)')
        .map((row) => row.read<String>('name'))
        .get();

    expect(db.schemaVersion, 15);
    expect(tables.toSet(), {
      'keychain_manifest_entries',
      'keychain_manifest_wallet_bindings',
      'keychain_manifest_nostr_keys',
      'wallet_backup_states',
    });
    expect(walletColumns, containsAll(['hide_on_home', 'auto_sweep_enabled']));
  });
}
