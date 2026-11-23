import 'package:drift/drift.dart';

import 'mempool_database.drift.dart';
import 'tables/mempool_servers_table.dart';
import 'tables/mempool_settings_table.dart';

class LegacyImportReceipts extends Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [MempoolServers, MempoolSettings, LegacyImportReceipts])
class MempoolDatabase extends $MempoolDatabase {
  MempoolDatabase(super.executor);

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
