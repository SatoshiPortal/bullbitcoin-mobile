part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [Transactions])
class TransactionsLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$TransactionsLocalDatasourceMixin {
  TransactionsLocalDatasource(super.attachedDatabase);

  Future<TransactionModel?> fetchByTxid(String txid) {
    return attachedDatabase.managers.transactions
        .filter((e) => e.txid(txid))
        .getSingleOrNull();
  }

  Future<void> store(TransactionModel row) {
    return into(transactions).insert(row.toCompanion(true));
  }
}
