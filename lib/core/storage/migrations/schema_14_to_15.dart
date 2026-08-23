import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Adds the final persistence required by deterministic products, backup, and
/// recovery. The archived schema-16/17 steps were never released, so their
/// final columns and tables are composed here.
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
    await m.createTable(schema.keychainManifestEntries);
    await m.createTable(schema.keychainManifestWalletBindings);
    await m.createTable(schema.keychainManifestNostrKeys);
    await m.createTable(schema.walletBackupStates);
  }
}
