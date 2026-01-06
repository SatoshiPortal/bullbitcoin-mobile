part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [PayjoinReceivers])
class PayjoinReceiversLocalDatasource extends DatabaseAccessor<SqliteDatabase>
    with _$PayjoinReceiversLocalDatasourceMixin {
  PayjoinReceiversLocalDatasource(super.attachedDatabase);

  Future<void> store(PayjoinReceiverRow row) {
    return into(payjoinReceivers).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<PayjoinReceiverRow?> fetchById(String id) {
    return attachedDatabase.managers.payjoinReceivers
        .filter((f) => f.id(id))
        .getSingleOrNull();
  }

  Future<List<PayjoinReceiverRow>> fetchAll({
    String? walletId,
    bool? isTestnet,
    bool? onlyUnfinished,
  }) {
    return attachedDatabase.managers.payjoinReceivers.filter((row) {
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

  Future<List<PayjoinReceiverRow>> fetchByTxId(String txId) {
    return attachedDatabase.managers.payjoinReceivers
        .filter((f) => f.txId(txId))
        .get();
  }
}
