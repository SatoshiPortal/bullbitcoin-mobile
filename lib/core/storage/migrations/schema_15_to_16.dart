import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema15To16 {
  static Future<void> migrate(Migrator m, Schema16 schema16) async {
    await m.createTable(schema16.keychainManifestBackupStates);
  }
}
