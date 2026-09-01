import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v14.dart' as v14;
import 'generated/schema_v15.dart' as v15;

/// Column names of [table], in declaration order.
Future<List<String>> columnsOf(DatabaseConnectionUser db, String table) => db
    .customSelect('PRAGMA table_info($table)')
    .map((row) => row.read<String>('name'))
    .get();

/// The shape v15 must have on every path. 14 is the last released schema, so
/// the never-released 15→16 (`descriptor`) and 16→17 (`label`) steps are folded
/// into the single 14→15 step and must show up here.
const walletBindingColumns = [
  'wallet_id',
  'entry_id',
  'child_seed_fingerprint',
  'network',
  'script_type',
  'provenance',
  'seed_passphrase_used',
  'descriptor',
  'label',
  'created_at',
  'updated_at',
];

/// The durable wallet-backup facts. The remote checkpoint trio is part of the
/// same never-released 15, so it belongs to the one 14→15 step rather than a
/// schema of its own.
const walletBackupStateColumns = [
  'id',
  'enabled',
  'local_revision',
  'uploaded_revision',
  'last_succeeded_at',
  'last_recovery_status',
  'unsupported_version',
  'recovery_state',
  'server_url',
  'remote_generation',
  'remote_etag',
  'remote_ciphertext_hash',
];

const walletMetadataColumnsAdded = [
  'hide_on_home',
  'auto_sweep_enabled',
  'provenance',
  'seed_passphrase_used',
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('15 is the app schema version', () {
    expect(SqliteDatabase.currentSchemaVersion, 15);
  });

  test('v14 to v15 on an empty database yields the final v15 shape', () async {
    final schema = await verifier.schemaAt(14);
    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 15);
    await db.close();

    final migrated = v15.DatabaseAtV15(schema.newConnection());
    addTearDown(migrated.close);

    expect(
      await columnsOf(migrated, 'keychain_manifest_wallet_bindings'),
      walletBindingColumns,
    );
    expect(
      await columnsOf(migrated, 'wallet_metadatas'),
      containsAll(walletMetadataColumnsAdded),
    );
    expect(
      await migrated.select(migrated.keychainManifestEntries).get(),
      isEmpty,
    );
    expect(
      await migrated.select(migrated.keychainManifestWalletBindings).get(),
      isEmpty,
    );
    expect(
      await migrated.select(migrated.keychainManifestNostrKeys).get(),
      isEmpty,
    );
    expect(
      await columnsOf(migrated, 'wallet_backup_states'),
      walletBackupStateColumns,
    );
    expect(await migrated.select(migrated.walletBackupStates).get(), isEmpty);
  });

  test('the migrated backup state carries a nullable checkpoint', () async {
    final schema = await verifier.schemaAt(14);
    final db = SqliteDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 15);
    await db.close();

    final migrated = v15.DatabaseAtV15(schema.newConnection());
    addTearDown(migrated.close);

    await migrated
        .into(migrated.walletBackupStates)
        .insert(v15.WalletBackupStatesCompanion.insert());
    final fresh = await migrated
        .select(migrated.walletBackupStates)
        .getSingle();
    expect(fresh.remoteGeneration, isNull);
    expect(fresh.remoteEtag, isNull);
    expect(fresh.remoteCiphertextHash, isNull);

    await migrated.customStatement(
      'UPDATE wallet_backup_states SET remote_generation = 4, '
      "remote_etag = 'etag', remote_ciphertext_hash = 'hash'",
    );
    final stored = await migrated
        .select(migrated.walletBackupStates)
        .getSingle();
    expect(stored.remoteGeneration, 4);
    expect(stored.remoteEtag, 'etag');
    expect(stored.remoteCiphertextHash, 'hash');
  });

  test('a fresh install and a v14 upgrade agree on the v15 shape', () async {
    final fresh = SqliteDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(fresh.schemaVersion, SqliteDatabase.currentSchemaVersion);

    final schema = await verifier.schemaAt(14);
    final upgraded = SqliteDatabase(schema.newConnection());
    addTearDown(upgraded.close);
    await verifier.migrateAndValidate(upgraded, 15);

    // Unordered: `wallet_metadatas` is ALTERed on the upgrade path, and SQLite
    // appends added columns, so its physical column order can never match a
    // fresh CREATE TABLE. Order is not part of the schema drift validates
    // (`migrateAndValidate` above) and the app reads columns by name; the
    // invariant that matters is that both paths expose the same set.
    for (final table in const [
      'wallet_metadatas',
      'keychain_manifest_entries',
      'keychain_manifest_wallet_bindings',
      'keychain_manifest_nostr_keys',
      'wallet_backup_states',
    ]) {
      expect(
        await columnsOf(upgraded, table),
        unorderedEquals(await columnsOf(fresh, table)),
        reason: '$table differs between onCreate and the 14 to 15 upgrade',
      );
    }
  });

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
      await oldDb
          .into(oldDb.walletMetadatas)
          .insert(
            v14.WalletMetadatasCompanion.insert(
              id: 'wallet-2',
              masterFingerprint: '99887766',
              xpubFingerprint: '55443322',
              isEncryptedVaultTested: 0,
              isPhysicalBackupTested: 0,
              xpub: 'xpub-2',
              externalPublicDescriptor: 'external-2',
              internalPublicDescriptor: 'internal-2',
              signer: 'remote',
              isDefault: 0,
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 15);
      await db.close();

      final migrated = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(migrated.close);
      await migrated.customStatement('PRAGMA foreign_keys = ON');
      final wallets = await migrated
          .select(migrated.walletMetadatas)
          .get()
          .then((rows) => {for (final row in rows) row.id: row});
      expect(wallets.keys, containsAll(['wallet-1', 'wallet-2']));
      final wallet = wallets['wallet-1']!;
      expect(wallet.hideOnHome, isNull);
      expect(wallet.autoSweepEnabled, isNull);
      expect(wallet.provenance, 'defaultSeed');
      expect(wallet.seedPassphraseUsed, isNull);
      expect(
        wallets['wallet-2']!.provenance,
        'externalSigner',
        reason: 'a non-default remote signer is backfilled from `signer`',
      );
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
          .get()
          .then((rows) => rows.firstWhere((row) => row.id == 'wallet-1'));
      expect(updatedWallet.hideOnHome, 1);
      expect(updatedWallet.autoSweepEnabled, 0);

      await migrated
          .into(migrated.keychainManifestEntries)
          .insert(
            v15.KeychainManifestEntriesCompanion.insert(
              entryId: 'entry-1',
              parentFingerprint: 'aabbccdd',
              derivationKind: 'bip85',
              derivationPath: "39'/0'/12'/100'",
              description: const Value('BTCPay wallet'),
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
              provenance: 'bip85',
              seedPassphraseUsed: const Value(0),
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

      await migrated.customStatement(
        "INSERT INTO keychain_manifest_entries "
        "SELECT 'entry-2', parent_fingerprint, derivation_kind, "
        'derivation_path, description, created_at, updated_at '
        "FROM keychain_manifest_entries WHERE entry_id = 'entry-1'",
      );
      expect(
        await migrated.select(migrated.keychainManifestEntries).get(),
        hasLength(2),
        reason: 'different seed roots may share a BIP32 account path',
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
          'network, script_type, provenance, seed_passphrase_used, '
          'descriptor, label, created_at, updated_at '
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
        "UPDATE keychain_manifest_entries SET description = 'backup key' "
        "WHERE entry_id = 'entry-1'",
      );
      await migrated.customStatement(
        'UPDATE wallet_backup_states SET enabled = 1, '
        "recovery_state = 'needsAttention', local_revision = 3 WHERE id = 1",
      );

      final entry = await migrated
          .select(migrated.keychainManifestEntries)
          .get()
          .then((entries) => entries.first);
      final binding = await migrated
          .select(migrated.keychainManifestWalletBindings)
          .getSingle();
      final backup = await migrated
          .select(migrated.walletBackupStates)
          .getSingle();
      expect(entry.updatedAt, 2);
      expect(binding.network, 'liquidMainnet');
      expect(entry.description, 'backup key');
      expect(backup.enabled, 1);
      expect(backup.recoveryState, 'needsAttention');
      expect(backup.localRevision, 3);
      expect(backup.uploadedRevision, 0);
    },
  );

  test(
    'v14 to v15 gives wallet bindings writable descriptor and label columns',
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
              isDefault: 0,
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 15);
      await db.close();

      final migrated = v15.DatabaseAtV15(schema.newConnection());
      addTearDown(migrated.close);
      await migrated
          .into(migrated.keychainManifestEntries)
          .insert(
            v15.KeychainManifestEntriesCompanion.insert(
              entryId: 'entry-1',
              parentFingerprint: 'aabbccdd',
              derivationKind: 'defaultSeedPassphrase',
              derivationPath: "m/84'/0'/0'",
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
              provenance: 'defaultSeedPassphrase',
              seedPassphraseUsed: const Value(1),
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      final inserted = await migrated
          .select(migrated.keychainManifestWalletBindings)
          .getSingle();
      expect(inserted.descriptor, isNull);
      expect(inserted.label, isNull);

      await migrated
          .update(migrated.keychainManifestWalletBindings)
          .write(
            const v15.KeychainManifestWalletBindingsCompanion(
              descriptor: Value('combined-descriptor'),
              label: Value('Passphrase wallet'),
            ),
          );
      final updated = await migrated
          .select(migrated.keychainManifestWalletBindings)
          .getSingle();
      expect(updated.descriptor, 'combined-descriptor');
      expect(updated.label, 'Passphrase wallet');
    },
  );
}
