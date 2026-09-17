import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:boltz_swaps/boltz_swaps.dart' hide SwapDirection;

/// One-shot copy of the app database's `swaps` table into the engine's own
/// [BoltzSwapsDatabase]. The copy and its completion marker commit in one
/// transaction (nothing half-done survives a crash), rows are
/// insert-if-absent (a retried import can never clobber state the engine
/// wrote since), and per-row mapping failures abort the transaction so the
/// import retries whole on the next launch. The source table is left
/// untouched — app schema v14 is published and immutable; a later schema
/// revision drops it.
class BoltzSwapsDbMigration {
  static const _migrationName = 'app-db-swaps-v1';

  final SqliteDatabase _appDb;
  final BoltzSwapsDatabase _swapsDb;
  final DriftSwapRowStore _rows;

  BoltzSwapsDbMigration({
    required this._appDb,
    required this._swapsDb,
    required this._rows,
  });

  Future<void> run() async {
    try {
      if (await _swapsDb.dataMigrationDone(_migrationName)) return;
      final oldRows = await _appDb.managers.swaps.get();
      await _swapsDb.runDataMigration(_migrationName, () async {
        for (final row in oldRows) {
          await _rows.insertIfAbsent(_toModel(row));
        }
      });
      log.info(
        'boltz_swaps db migration: ${oldRows.length} swap row(s) imported',
      );
    } catch (e) {
      log.severe(
        message: 'boltz_swaps db migration failed — will retry next launch',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  /// Rows written before app-schema v13 stored refunded swaps as
  /// 'completed'; carry the backfill across like the old mapper did.
  static String _status(SwapRow swap) {
    if (swap.status == 'completed' && swap.refundTxid != null) {
      return 'refunded';
    }
    return swap.status;
  }

  static SwapModel _toModel(SwapRow swap) {
    switch (swap.direction) {
      case SwapDirection.receive:
        return SwapModel.lnReceive(
          id: swap.id,
          type: swap.type,
          status: _status(swap),
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
      case SwapDirection.send:
        return SwapModel.lnSend(
          id: swap.id,
          type: swap.type,
          status: _status(swap),
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
      case SwapDirection.onchain:
        return SwapModel.chain(
          id: swap.id,
          type: swap.type,
          status: _status(swap),
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
