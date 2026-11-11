import 'package:boltz_swaps/src/data/db/boltz_swaps_database.dart';
import 'package:boltz_swaps/src/data/models/swap_model.dart';
import 'package:boltz_swaps/src/data/swap_storage.dart';
import 'package:drift/drift.dart';

/// The package's own persistence over [BoltzSwapsDatabase].
class DriftSwapRowStore implements SwapRowStore {
  final BoltzSwapsDatabase _db;

  DriftSwapRowStore(this._db);

  @override
  Future<void> store(SwapModel swapModel) async {
    await _db.into(_db.swaps).insertOnConflictUpdate(swapModel.toSqlite());
  }

  /// Migration-only write: inserts the row when absent and never overwrites
  /// an existing one, so a re-imported legacy row can't clobber state the
  /// engine has since written.
  Future<void> insertIfAbsent(SwapModel swapModel) async {
    await _db
        .into(_db.swaps)
        .insert(swapModel.toSqlite(), mode: InsertMode.insertOrIgnore);
  }

  @override
  Future<SwapModel?> fetch(String swapId) async {
    final row = await _db.managers.swaps
        .filter((f) => f.id(swapId))
        .getSingleOrNull();
    if (row == null) return null;
    return SwapRowMapper.fromSqlite(row);
  }

  @override
  Stream<SwapModel> watch(String swapId) => _db.managers.swaps
      .filter((f) => f.id(swapId))
      .watchSingleOrNull()
      .where((row) => row != null)
      .map((row) => SwapRowMapper.fromSqlite(row!));

  @override
  Future<List<SwapModel>> fetchAll({String? walletId, bool? isTestnet}) async {
    final all = await _db.managers.swaps.filter((f) {
      Expression<bool> expr = const Constant(true);
      if (walletId != null) {
        expr =
            expr &
            (f.sendWalletId.equals(walletId) |
                f.receiveWalletId.equals(walletId));
      }
      if (isTestnet != null) {
        expr = expr & f.isTestnet.equals(isTestnet);
      }
      return expr;
    }).get();
    return all.map(SwapRowMapper.fromSqlite).toList();
  }

  @override
  Future<SwapModel?> fetchByTxId(String txId) async {
    final row = await _db.managers.swaps
        .filter(
          (f) =>
              f.sendTxid.equals(txId) |
              f.receiveTxid.equals(txId) |
              f.refundTxid.equals(txId),
        )
        .getSingleOrNull();
    if (row == null) return null;
    return SwapRowMapper.fromSqlite(row);
  }

  @override
  Future<void> trash(String swapId) async {
    await _db.managers.swaps.filter((f) => f.id(swapId)).delete();
  }
}

/// SwapModel <-> SwapRow. Direction is derived from the model's variant.
class SwapRowMapper {
  /// Rows written before app-schema v13 stored refunded swaps as
  /// 'completed'. The v13 migration backfilled them, but stay defensive for
  /// rows written by an older app version against a migrated database.
  static String _backfillRefundedStatus(SwapRow swap) {
    if (swap.status == 'refunded') return swap.status;
    if (swap.status == 'completed' && swap.refundTxid != null) {
      return 'refunded';
    }
    return swap.status;
  }

  static SwapModel fromSqlite(SwapRow swap) {
    switch (swap.direction) {
      case SwapRowDirection.receive:
        return SwapModel.lnReceive(
          id: swap.id,
          type: swap.type,
          status: _backfillRefundedStatus(swap),
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          receiveWalletId: swap.receiveWalletId!,
          receiveAddress: swap.receiveAddress,
          receiveTxid: swap.receiveTxid,
          wasDirectPayment: swap.wasDirectPayment,
          completionTime: swap.completionTime,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          invoice: swap.invoice!,
          recovered: swap.recovered,
        );
      case SwapRowDirection.send:
        return SwapModel.lnSend(
          id: swap.id,
          type: swap.type,
          status: _backfillRefundedStatus(swap),
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          sendWalletId: swap.sendWalletId!,
          paymentAddress: swap.paymentAddress!,
          paymentAmount: swap.paymentAmount!,
          completionTime: swap.completionTime,
          invoice: swap.invoice!,
          sendTxid: swap.sendTxid,
          preimage: swap.preimage,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          refundFees: swap.refundFees,
          recovered: swap.recovered,
        );
      case SwapRowDirection.onchain:
        return SwapModel.chain(
          id: swap.id,
          type: swap.type,
          status: _backfillRefundedStatus(swap),
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          completionTime: swap.completionTime,
          receiveWalletId: swap.receiveWalletId,
          sendWalletId: swap.sendWalletId!,
          paymentAddress: swap.paymentAddress!,
          paymentAmount: swap.paymentAmount!,
          receiveAddress: swap.receiveAddress,
          receiveTxid: swap.receiveTxid,
          sendTxid: swap.sendTxid,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          refundFees: swap.refundFees,
          serverNetworkFees: swap.serverNetworkFees,
          recovered: swap.recovered,
        );
    }
  }
}

extension SwapModelToSqliteX on SwapModel {
  SwapRow toSqlite() {
    switch (this) {
      case final LnReceiveSwapModel swap:
        return SwapRow(
          id: swap.id,
          type: swap.type,
          direction: SwapRowDirection.receive,
          status: swap.status,
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          receiveWalletId: swap.receiveWalletId,
          invoice: swap.invoice,
          receiveAddress: swap.receiveAddress,
          receiveTxid: swap.receiveTxid,
          wasDirectPayment: swap.wasDirectPayment,
          completionTime: swap.completionTime,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          recovered: swap.recovered,
        );
      case final LnSendSwapModel swap:
        return SwapRow(
          id: swap.id,
          type: swap.type,
          direction: SwapRowDirection.send,
          status: swap.status,
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          completionTime: swap.completionTime,
          sendWalletId: swap.sendWalletId,
          invoice: swap.invoice,
          paymentAddress: swap.paymentAddress,
          paymentAmount: swap.paymentAmount,
          sendTxid: swap.sendTxid,
          preimage: swap.preimage,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          refundFees: swap.refundFees,
          wasDirectPayment: false,
          recovered: swap.recovered,
        );
      case final ChainSwapModel swap:
        return SwapRow(
          id: swap.id,
          type: swap.type,
          direction: SwapRowDirection.onchain,
          status: swap.status,
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          completionTime: swap.completionTime,
          receiveWalletId: swap.receiveWalletId,
          sendWalletId: swap.sendWalletId,
          paymentAddress: swap.paymentAddress,
          paymentAmount: swap.paymentAmount,
          sendTxid: swap.sendTxid,
          receiveAddress: swap.receiveAddress,
          receiveTxid: swap.receiveTxid,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          refundFees: swap.refundFees,
          serverNetworkFees: swap.serverNetworkFees,
          wasDirectPayment: false,
          recovered: swap.recovered,
        );
    }
  }
}
