import 'package:drift/drift.dart';

import 'exchange_database.drift.dart';

class ExchangeApiCredentials extends Table {
  TextColumn get environment => text().customConstraint(
    "NOT NULL CHECK (environment IN ('mainnet', 'testnet'))",
  )();
  TextColumn get encodedRecord => text().nullable()();

  @override
  Set<Column> get primaryKey => {environment};
}

class ExchangeBasicAuth extends Table {
  IntColumn get settingsId => integer()();
  TextColumn get username => text().nullable()();
  TextColumn get password => text().nullable()();

  @override
  Set<Column> get primaryKey => {settingsId};
}

class LegacyImportReceipts extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [ExchangeApiCredentials, ExchangeBasicAuth, LegacyImportReceipts],
)
class ExchangeDatabase extends $ExchangeDatabase {
  static const schema = 1;

  ExchangeDatabase(super.executor);

  @override
  int get schemaVersion => schema;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      for (final table in allTables) {
        final existing = await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable(table.actualTableName)],
        ).getSingleOrNull();
        if (existing == null) await migrator.createTable(table);
      }
    }),
  );
}
