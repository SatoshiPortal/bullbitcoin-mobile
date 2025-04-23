import 'package:bb_mobile/core/transaction/data/models/transactions_table.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'sqlite_datasource.g.dart';

TableInfo<Table, dynamic> typeToTable<T extends Insertable>(Type type) {
  final db = SqliteDatasource();

  if (type == Transactions) return db.transactions;

  throw UnsupportedError('Unknown table type $T');
}

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

  Future<Transaction?> fetchTransaction(String txid) async {
    return await (select(transactions)
          ..where((table) => table.txid.equals(txid)))
        .getSingleOrNull();
  }

  Future<void> store<T extends Insertable>(T entity) async {
    final table = typeToTable(entity.runtimeType);
    await into(table).insertOnConflictUpdate(entity);
  }

  void clearCacheTables() {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      delete(table).go();
    }
  }
}
