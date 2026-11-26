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

/// Exchange writes that ended with an unknown outcome (schema 2). An entry is
/// open while [settledAtMs] is null. [request] is a JSON object of text
/// values: what was sent, without secrets.
@DataClassName('UnknownWriteRow')
class UnknownWrites extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get environment => text().customConstraint(
    "NOT NULL CHECK (environment IN ('mainnet', 'testnet'))",
  )();
  IntColumn get sessionEpoch => integer().nullable()();
  TextColumn get orderId => text().nullable()();
  TextColumn get request => text()();
  IntColumn get recordedAtMs => integer()();
  IntColumn get settledAtMs => integer().nullable()();
  TextColumn get settlement => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ExchangeApiCredentials,
    ExchangeBasicAuth,
    LegacyImportReceipts,
    UnknownWrites,
  ],
)
class ExchangeDatabase extends $ExchangeDatabase {
  static const schema = 2;

  ExchangeDatabase(super.executor);

  @override
  int get schemaVersion => schema;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      for (final table in allTables) {
        if (!await _hasTable(table.actualTableName)) {
          await migrator.createTable(table);
        }
      }
    }),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from >= to || to > schema) {
        throw const _UnsupportedExchangeSchema();
      }
      await transaction(() async {
        if (from < 2 && !await _hasTable('unknown_writes')) {
          await migrator.createTable(unknownWrites);
        }
      });
    },
  );

  Future<bool> _hasTable(String name) async =>
      await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable(name)],
      ).getSingleOrNull() !=
      null;
}

final class _UnsupportedExchangeSchema implements Exception {
  const _UnsupportedExchangeSchema();
}
