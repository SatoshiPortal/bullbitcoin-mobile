import 'package:drift/drift.dart';

import 'preferences_database.drift.dart';
import 'owner_settings_table.dart';
import 'recoverbull_permissions_table.dart';

class LegacyImportReceipts extends Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    OwnerSettings,
    RecoverbullPermissions,
    RecoverbullPermissionOverrides,
    LegacyImportReceipts,
  ],
)
class PreferencesDatabase extends $PreferencesDatabase {
  PreferencesDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await transaction(() async {
        for (final table in allTables) {
          final exists = await customSelect(
            'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
            variables: [
              const Variable('table'),
              Variable(table.actualTableName),
            ],
          ).getSingleOrNull();
          if (exists == null) await m.createTable(table);
        }
      });
    },
  );
}
