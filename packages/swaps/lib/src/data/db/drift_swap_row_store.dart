import 'package:swaps/src/log.dart';
import 'package:swaps/src/data/db/boltz_swaps_database.dart';
import 'package:swaps/src/data/models/swap_model.dart';
import 'package:swaps/src/data/swap_storage.dart';
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
      .map((row) => row == null ? null : SwapRowMapper.fromSqlite(row))
      .where((model) => model != null)
      .cast<SwapModel>();

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
    return [for (final row in all) ?SwapRowMapper.fromSqlite(row)];
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
        .get();
    for (final candidate in row) {
      if (SwapRowMapper.fromSqlite(candidate) case final model?) return model;
    }
    return null;
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

  /// Null for a row missing a field its swap type requires; such a row is
  /// skipped (and logged) so one damaged row never stops every other swap.
  static SwapModel? fromSqlite(SwapRow swap) {
    final model = _fromSqlite(swap);
    if (model == null) {
      swapsLog.warning('SWAPS: swap row ${swap.id} is incomplete — skipped');
    }
    return model;
  }

  static SwapModel? _fromSqlite(SwapRow swap) {
    switch (swap.direction) {
      case SwapRowDirection.receive:
        final (receiveWalletId, invoice) = (swap.receiveWalletId, swap.invoice);
        if (receiveWalletId == null || invoice == null) return null;
        return SwapModel.lnReceive(
          id: swap.id,
          type: swap.type,
          status: _backfillRefundedStatus(swap),
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          receiveWalletId: receiveWalletId,
          receiveAddress: swap.receiveAddress,
          receiveTxid: swap.receiveTxid,
          wasDirectPayment: swap.wasDirectPayment,
          completionTime: swap.completionTime,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          invoice: invoice,
          recovered: swap.recovered,
          provider: swap.provider,
        );
      case SwapRowDirection.send:
        final (sendWalletId, paymentAddress, paymentAmount, invoice) = (
          swap.sendWalletId,
          swap.paymentAddress,
          swap.paymentAmount,
          swap.invoice,
        );
        if (sendWalletId == null ||
            paymentAddress == null ||
            paymentAmount == null ||
            invoice == null) {
          return null;
        }
        return SwapModel.lnSend(
          id: swap.id,
          type: swap.type,
          status: _backfillRefundedStatus(swap),
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          sendWalletId: sendWalletId,
          paymentAddress: paymentAddress,
          paymentAmount: paymentAmount,
          completionTime: swap.completionTime,
          invoice: invoice,
          sendTxid: swap.sendTxid,
          pendingLockupTx: swap.pendingLockupTx,
          pendingLockupTxid: swap.pendingLockupTxid,
          preimage: swap.preimage,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          refundFees: swap.refundFees,
          recovered: swap.recovered,
          provider: swap.provider,
        );
      case SwapRowDirection.onchain:
        final (sendWalletId, paymentAddress, paymentAmount) = (
          swap.sendWalletId,
          swap.paymentAddress,
          swap.paymentAmount,
        );
        if (sendWalletId == null ||
            paymentAddress == null ||
            paymentAmount == null) {
          return null;
        }
        return SwapModel.chain(
          id: swap.id,
          type: swap.type,
          status: _backfillRefundedStatus(swap),
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          completionTime: swap.completionTime,
          receiveWalletId: swap.receiveWalletId,
          sendWalletId: sendWalletId,
          paymentAddress: paymentAddress,
          paymentAmount: paymentAmount,
          receiveAddress: swap.receiveAddress,
          receiveTxid: swap.receiveTxid,
          sendTxid: swap.sendTxid,
          pendingLockupTx: swap.pendingLockupTx,
          pendingLockupTxid: swap.pendingLockupTxid,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          refundFees: swap.refundFees,
          serverNetworkFees: swap.serverNetworkFees,
          recovered: swap.recovered,
          provider: swap.provider,
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
          provider: swap.provider,
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
          pendingLockupTx: swap.pendingLockupTx,
          pendingLockupTxid: swap.pendingLockupTxid,
          preimage: swap.preimage,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          refundFees: swap.refundFees,
          wasDirectPayment: false,
          recovered: swap.recovered,
          provider: swap.provider,
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
          pendingLockupTx: swap.pendingLockupTx,
          pendingLockupTxid: swap.pendingLockupTxid,
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
          provider: swap.provider,
        );
    }
  }
}
