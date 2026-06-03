import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 14 to 15.
///
/// Adds local keychain manifest entries for Bull-created BIP85 materializations.
class Schema14To15 {
  static Future<void> migrate(Migrator m, Schema15 schema15) async {
    await m.createTable(schema15.keychainManifestEntries);
    await m.createTable(schema15.keychainManifestWalletBindings);
  }
}
