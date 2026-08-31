import 'package:bb_mobile/core/storage/sqlite_database.dart' as root;
import 'package:bull_swap/bull_swap.dart';
import 'package:drift/drift.dart';

class RootSwapLegacySource implements SwapLegacyDataPort {
  final root.SqliteDatabase _db;

  RootSwapLegacySource(this._db);

  @override
  Future<List<SwapsCompanion>> readSwaps() async {
    final rows = await _db.select(_db.swaps).get();
    return rows
        .map(
          (r) => SwapsCompanion.insert(
            id: r.id,
            type: r.type,
            direction: SwapDirection.values.byName(r.direction.name),
            status: r.status,
            isTestnet: r.isTestnet,
            keyIndex: r.keyIndex,
            creationTime: r.creationTime,
            completionTime: Value(r.completionTime),
            receiveWalletId: Value(r.receiveWalletId),
            sendWalletId: Value(r.sendWalletId),
            invoice: Value(r.invoice),
            paymentAddress: Value(r.paymentAddress),
            paymentAmount: Value(r.paymentAmount),
            receiveAddress: Value(r.receiveAddress),
            receiveTxid: Value(r.receiveTxid),
            sendTxid: Value(r.sendTxid),
            preimage: Value(r.preimage),
            refundAddress: Value(r.refundAddress),
            refundTxid: Value(r.refundTxid),
            boltzFees: Value(r.boltzFees),
            lockupFees: Value(r.lockupFees),
            claimFees: Value(r.claimFees),
            refundFees: Value(r.refundFees),
            serverNetworkFees: Value(r.serverNetworkFees),
            wasDirectPayment: Value(r.wasDirectPayment),
            recovered: Value(r.recovered),
            providerId: const Value('boltz'),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<AutoSwapCompanion>> readAutoSwaps() async {
    final rows = await _db.select(_db.autoSwap).get();
    return rows
        .map(
          (r) => AutoSwapCompanion.insert(
            id: Value(r.id),
            enabled: Value(r.enabled),
            balanceThresholdSats: r.balanceThresholdSats,
            triggerBalanceSats: r.triggerBalanceSats,
            feeThresholdPercent: r.feeThresholdPercent,
            blockTillNextExecution: Value(r.blockTillNextExecution),
            alwaysBlock: Value(r.alwaysBlock),
            recipientWalletId: Value(r.recipientWalletId),
            showWarning: Value(r.showWarning),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<OrderSwapsCompanion>> readOrderSwaps() async {
    final rows = await _db.select(_db.orderSwaps).get();
    return rows
        .map(
          (r) => OrderSwapsCompanion.insert(
            localId: r.localId,
            requestId: Value(r.requestId),
            orderId: Value(r.orderId),
            purpose: r.purpose,
            environment: r.environment,
            inNetwork: r.inNetwork,
            outNetwork: r.outNetwork,
            isInAmountFixed: r.isInAmountFixed,
            requestedAmountSat: r.requestedAmountSat,
            quotedAmountSat: Value(r.quotedAmountSat),
            sourceWalletId: Value(r.sourceWalletId),
            destinationWalletId: Value(r.destinationWalletId),
            destination: r.destination,
            fallback: r.fallback,
            bitcoinAddress: Value(r.bitcoinAddress),
            liquidAddress: Value(r.liquidAddress),
            lightningInvoice: Value(r.lightningInvoice),
            payinAmountSat: Value(r.payinAmountSat),
            payoutAmountSat: Value(r.payoutAmountSat),
            payinCurrency: Value(r.payinCurrency),
            payoutCurrency: Value(r.payoutCurrency),
            payinMethod: Value(r.payinMethod),
            payoutMethod: Value(r.payoutMethod),
            orderType: Value(r.orderType),
            orderStatus: Value(r.orderStatus),
            payinStatus: Value(r.payinStatus),
            payoutStatus: Value(r.payoutStatus),
            messageCode: Value(r.messageCode),
            bitcoinTransactionId: Value(r.bitcoinTransactionId),
            liquidTransactionId: Value(r.liquidTransactionId),
            localPayinTransactionId: Value(r.localPayinTransactionId),
            signedPayinTransaction: Value(r.signedPayinTransaction),
            payinIsPsbt: Value(r.payinIsPsbt),
            orderNumber: Value(r.orderNumber),
            createdAt: r.createdAt,
            serverCreatedAt: Value(r.serverCreatedAt),
            confirmationDeadline: Value(r.confirmationDeadline),
            sentAt: Value(r.sentAt),
            localStatus: r.localStatus,
            lastPolledAt: Value(r.lastPolledAt),
            note: Value(r.note),
            serverCompletedAt: Value(r.serverCompletedAt),
            labelsAppliedAt: Value(r.labelsAppliedAt),
            providerId: const Value('bull'),
          ),
        )
        .toList(growable: false);
  }
}
