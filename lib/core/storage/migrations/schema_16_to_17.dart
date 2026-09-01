import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Adds the persistence required by deterministic products, backup, and
/// recovery on top of the normalized signer schema of v16: wallet preference
/// and provenance columns, the keychain manifest tables, and the durable
/// wallet-backup state.
///
/// Provenance is derived from the wallet's primary signer row (position 0),
/// which for wallets migrated from v15 is exactly the former `signer` column.
class Schema16To17 {
  static Future<void> migrate(Migrator m, Schema17 schema) async {
    await m.addColumn(
      schema.walletMetadatas,
      schema.walletMetadatas.hideOnHome,
    );
    await m.addColumn(
      schema.walletMetadatas,
      schema.walletMetadatas.autoSweepEnabled,
    );
    await m.addColumn(
      schema.walletMetadatas,
      schema.walletMetadatas.provenance,
    );
    await m.addColumn(
      schema.walletMetadatas,
      schema.walletMetadatas.seedPassphraseUsed,
    );
    await m.database.customStatement(
      "UPDATE wallet_metadatas SET provenance = CASE "
      "WHEN is_default = 1 THEN 'defaultSeed' "
      "WHEN (SELECT signer FROM wallet_signers "
      "WHERE wallet_signers.wallet_id = wallet_metadatas.id "
      "ORDER BY position LIMIT 1) = 'local' THEN 'importedMnemonic' "
      "WHEN (SELECT signer FROM wallet_signers "
      "WHERE wallet_signers.wallet_id = wallet_metadatas.id "
      "ORDER BY position LIMIT 1) = 'remote' THEN 'externalSigner' "
      "ELSE 'watchOnly' END",
    );
    await m.createTable(schema.keychainManifestEntries);
    await m.createTable(schema.keychainManifestWalletBindings);
    await m.createTable(schema.keychainManifestNostrKeys);
    await m.createTable(schema.walletBackupStates);
  }
}
