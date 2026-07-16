import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Adds the local-only wallet metadata backup activation and progress state.
class Schema16To17 {
  static Future<void> migrate(Migrator m, Schema17 schema17) async {
    await m.createTable(schema17.walletMetadataBackupStates);
  }
}
