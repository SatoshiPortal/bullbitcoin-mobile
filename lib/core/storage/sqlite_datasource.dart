import 'package:bb_mobile/core/transaction/data/models/transactions_table.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'sqlite_datasource.g.dart';

@DriftDatabase(tables: [Transactions])
class SqliteDatasource extends _$SqliteDatasource {
  SqliteDatasource([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bull_sqlite',
      native: const DriftNativeOptions(), // TODO(azad): constant path
    );
  }

  Future<void> store<T extends Insertable>(T entity) async {
    final table = _typeToTable(entity.runtimeType);
    await into(table).insertOnConflictUpdate(entity);
  }

  Future<void> clearCacheTables() async {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      await delete(table).go();
    }
  }

  TableInfo<Table, dynamic> _typeToTable<T extends Insertable>(Type type) {
    final lowerPluralType = '${type.toString().toLowerCase()}s';
    for (final table in allTables) {
      if (table.actualTableName == lowerPluralType) {
        return table;
      }
    }

    throw Exception('$lowerPluralType does not match tables $allTables');
  }
}
