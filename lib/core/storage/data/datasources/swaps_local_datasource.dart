part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [Swaps])
class SwapsLocalDatasource extends DatabaseAccessor<SqliteDatabase> with _$SwapsLocalDatasourceMixin {
  SwapsLocalDatasource(super.attachedDatabase);

  Future<void> store(SwapRow row) {
    return into(swaps).insertOnConflictUpdate(row.toCompanion(true));
  }

  Future<SwapRow?> fetchById(String id) {
    return attachedDatabase.managers.swaps
        .filter((f) => f.id(id))
        .getSingleOrNull();
  }

  Future<List<SwapRow>> fetchAll({String? walletId, bool? isTestnet}) {
    return attachedDatabase.managers.swaps.filter((f) {
      Expression<bool> expr = const Constant(true);

      if (walletId != null) {
        expr = expr &
            (f.sendWalletId.equals(walletId) |
                f.receiveWalletId.equals(walletId));
      }

      if (isTestnet != null) {
        expr = expr & f.isTestnet.equals(isTestnet);
      }

      return expr;
    }).get();
  }

  Future<SwapRow?> fetchByTxId(String txId) {
    return attachedDatabase.managers.swaps
        .filter(
          (f) =>
              f.sendTxid.equals(txId) |
              f.receiveTxid.equals(txId) |
              f.refundTxid.equals(txId),
        )
        .getSingleOrNull();
  }

  Future<void> trashById(String id) {
    return attachedDatabase.managers.swaps.filter((f) => f.id(id)).delete();
  }
}
