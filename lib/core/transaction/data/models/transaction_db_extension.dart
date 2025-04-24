import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/locator.dart';

extension TransactionDb on Transaction {
  Future<void> store() async {
    await locator<SqliteDatasource>().store<Transaction>(this);
  }

  static Future<Transaction?> fetch(String txid) async {
    final db = locator<SqliteDatasource>();
    final table = db.transactions;
    return await (db.select(table)..where((table) => table.txid.equals(txid)))
        .getSingleOrNull();
  }

  static Future<List<Transaction>> all(String txid) async {
    final db = locator<SqliteDatasource>();
    final table = db.transactions;
    return await db.select(table).get();
  }
}
