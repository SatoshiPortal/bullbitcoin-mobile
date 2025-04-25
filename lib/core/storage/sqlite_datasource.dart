import 'package:bb_mobile/core/transaction/data/models/transactions_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_table.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'sqlite_datasource.g.dart';

@DriftDatabase(tables: [Transactions, WalletMetadatas])
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

  Future<void> clearCacheTables() async {
    final cacheTables = [transactions];

    for (final table in cacheTables) {
      await delete(table).go();
    }
  }
}
