import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema16To17 {
  static Future<void> migrate(Migrator m, Schema17 schema17) async {
    await m.database.transaction(() async {
      await m.createTable(schema17.walletBackupStates);
      await m.createTable(schema17.walletBackupControls);
      await m.createTable(schema17.keychainNostrKeys);
      await m.addColumn(
        schema17.bullVaultRecords,
        schema17.bullVaultRecords.descriptorTestedAt,
      );
      await m.addColumn(
        schema17.bullVaultRecords,
        schema17.bullVaultRecords.serverTestedAt,
      );
      await m.database.customStatement('PRAGMA user_version = 17');
    });
  }
}
