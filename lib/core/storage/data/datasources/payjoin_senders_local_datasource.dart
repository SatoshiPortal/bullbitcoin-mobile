part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [PayjoinSenders])
class PayjoinSendersLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$PayjoinSendersLocalDatasourceMixin {
  PayjoinSendersLocalDatasource(super.attachedDatabase);

  Future<void> store(PayjoinSenderRow row) {
    return into(payjoinSenders).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<PayjoinSenderRow?> fetchByUri(String uri) {
    return attachedDatabase.managers.payjoinSenders
        .filter((f) => f.uri(uri))
        .getSingleOrNull();
  }

  Future<List<PayjoinSenderRow>> fetchAll({
    String? walletId,
    bool? isTestnet,
    bool? onlyUnfinished,
  }) {
    return attachedDatabase.managers.payjoinSenders.filter((row) {
      Expression<bool> expr = const Constant(true);

      if (onlyUnfinished == true) {
        expr =
            expr & row.isExpired.equals(false) & row.isCompleted.equals(false);
      }

      if (walletId != null) {
        expr = expr & row.walletId.equals(walletId);
      }

      if (isTestnet != null) {
        expr = expr & row.isTestnet.equals(isTestnet);
      }

      return expr;
    }).get();
  }

  Future<List<PayjoinSenderRow>> fetchByTxId(String txId) {
    return attachedDatabase.managers.payjoinSenders
        .filter((f) => f.txId(txId))
        .get();
  }
}
