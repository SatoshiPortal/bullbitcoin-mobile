import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:swaps/swaps.dart' hide SwapDirection;

/// Sqlite (drift) mapping for the package's SwapModel — the app-side half of
/// the swaps package's SwapRowStore contract.
class SwapModelSqliteMapper {
  /// Rows written before schema v13 stored refunded swaps as 'completed'.
  /// The v13 migration backfills them, but stay defensive for rows written
  /// by an older app version against an already-migrated database.
  static String _backfillRefundedStatus(SwapRow swap) {
    if (swap.status == SwapStatus.completed.name && swap.refundTxid != null) {
      return SwapStatus.refunded.name;
    }
    return swap.status;
  }

  static SwapModel fromSqlite(SwapRow swap) {
    switch (swap.direction) {
      case SwapDirection.receive:
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
      case SwapDirection.send:
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
      case SwapDirection.onchain:
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
    if (this is LnReceiveSwapModel) {
      final swap = this as LnReceiveSwapModel;
      return SwapRow(
        id: swap.id,
        type: swap.type,
        direction: SwapDirection.receive,
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
    } else if (this is LnSendSwapModel) {
      final swap = this as LnSendSwapModel;
      return SwapRow(
        id: swap.id,
        type: swap.type,
        direction: SwapDirection.send,
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
    } else if (this is ChainSwapModel) {
      final swap = this as ChainSwapModel;

      return SwapRow(
        id: swap.id,
        type: swap.type,
        direction: SwapDirection.onchain,
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
    } else {
      throw UnsupportedError('$SwapModel unsupported: $runtimeType');
    }
  }
}
