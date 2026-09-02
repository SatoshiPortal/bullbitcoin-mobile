import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Adds the final persistence required by deterministic products, backup, and
/// recovery. Schema 14 is the last released version, so everything this branch
/// adds — including the wallet-binding descriptor and label columns that were
/// briefly carried as separate, never-released 15→16 and 16→17 steps — is
/// composed into this single step and into the tables it creates.
class Schema14To15 {
  static Future<void> migrate(Migrator m, Schema15 schema) async {
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
      "WHEN signer = 'local' THEN 'importedMnemonic' "
      "WHEN signer = 'remote' THEN 'externalSigner' "
      "ELSE 'watchOnly' END",
    );
    await m.createTable(schema.keychainManifestEntries);
    await m.createTable(schema.keychainManifestWalletBindings);
    await m.createTable(schema.keychainManifestNostrKeys);
    await m.createTable(schema.walletBackupStates);
  }
}
