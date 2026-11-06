import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'pricer_database.g.dart';

@DataClassName('CachedPriceRow')
class CachedPrices extends Table {
  TextColumn get network => text()();
  TextColumn get currency => text()();
  RealColumn get fiatAmount => real()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {network, currency};
}

@DriftDatabase(tables: [CachedPrices])
final class PricerDatabase extends _$PricerDatabase {
  static const schema = 1;

  PricerDatabase._(super.executor);

  factory PricerDatabase.open(String path) {
    return PricerDatabase._(
      NativeDatabase.createInBackground(
        File(path),
        setup: (database) {
          database.execute('PRAGMA busy_timeout = 2000;');
          database.execute('PRAGMA journal_mode = WAL;');
          database.execute('PRAGMA synchronous = NORMAL;');
        },
      ),
    );
  }

  factory PricerDatabase.forTesting(QueryExecutor executor) = PricerDatabase._;

  @override
  int get schemaVersion => schema;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      for (final table in allTables) {
        await migrator.deleteTable(table.actualTableName);
      }
      await migrator.createAll();
    },
  );
}
