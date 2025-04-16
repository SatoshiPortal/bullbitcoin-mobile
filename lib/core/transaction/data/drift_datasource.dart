import 'package:bb_mobile/core/transaction/data/models/drift_mapper.dart';
import 'package:bb_mobile/core/transaction/data/models/transactions_table.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'drift_datasource.g.dart';

@DriftDatabase(tables: [Transactions])
class DriftDatasource extends _$DriftDatasource {
  DriftDatasource([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'bull_sqlite',
      native: const DriftNativeOptions(), // TODO(azad): constant path
    );
  }

  Future<Tx?> fetchTransaction(String txid) async {
    final result = await (select(transactions)
          ..where((table) => table.txid.equals(txid)))
        .getSingleOrNull();

    return DriftMapper.fromDrift(result);
  }

  Future<void> storeTransaction(Tx tx) async {
    final driftTx = DriftMapper.toDrift(tx);
    await into(transactions).insertOnConflictUpdate(driftTx);
  }
}
