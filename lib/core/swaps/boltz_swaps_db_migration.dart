import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:swaps/swaps.dart' hide SwapDirection;

/// One-shot copy of the app database's `swaps` table into the engine's own
/// [BoltzSwapsDatabase]. The copy and its completion marker commit in one
/// transaction (nothing half-done survives a crash), rows are
/// insert-if-absent (a retried import can never clobber state the engine
/// wrote since). A row missing a field its swap kind requires is skipped and
/// logged rather than blocking every other swap from importing. The source
/// table is left
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
      var skipped = 0;
      await _swapsDb.runDataMigration(_migrationName, () async {
        for (final row in oldRows) {
          final model = _toModel(row);
          if (model == null) {
            skipped++;
            log.warning(
              'boltz_swaps db migration: skipped incomplete '
              '${row.direction.name} swap ${row.id}',
            );
            continue;
          }
          await _rows.insertIfAbsent(model);
        }
      });
      log.fine(
        'boltz_swaps db migration: ${oldRows.length - skipped} swap row(s) '
        'imported, $skipped skipped',
      );
    } catch (e) {
      log.severe(
        message: 'boltz_swaps db migration failed — will retry next launch',
        error: e.runtimeType,
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

  static SwapModel? _toModel(SwapRow swap) {
    switch (swap) {
      case SwapRow(
        direction: SwapDirection.receive,
        receiveWalletId: final receiveWalletId?,
        invoice: final invoice?,
      ):
        return SwapModel.lnReceive(
          id: swap.id,
          type: swap.type,
          status: _status(swap),
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
        );
      case SwapRow(
        direction: SwapDirection.send,
        sendWalletId: final sendWalletId?,
        paymentAddress: final paymentAddress?,
        paymentAmount: final paymentAmount?,
        invoice: final invoice?,
      ):
        return SwapModel.lnSend(
          id: swap.id,
          type: swap.type,
          status: _status(swap),
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          sendWalletId: sendWalletId,
          paymentAddress: paymentAddress,
          paymentAmount: paymentAmount,
          completionTime: swap.completionTime,
          invoice: invoice,
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
      case SwapRow(
        direction: SwapDirection.onchain,
        sendWalletId: final sendWalletId?,
        paymentAddress: final paymentAddress?,
        paymentAmount: final paymentAmount?,
      ):
        return SwapModel.chain(
          id: swap.id,
          type: swap.type,
          status: _status(swap),
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
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          refundFees: swap.refundFees,
          serverNetworkFees: swap.serverNetworkFees,
          recovered: swap.recovered,
        );
      default:
        return null;
    }
  }
}
