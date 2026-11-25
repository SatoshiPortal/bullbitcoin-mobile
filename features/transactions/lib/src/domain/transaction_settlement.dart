import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinStatus;
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';

import 'entities/transaction.dart';

/// The wallet transaction whose confirmation settles a payment: where to look
/// for it, never the transaction the screen displays.
final class TransactionSettlementTarget {
  final String walletId;
  final String txId;

  /// Whether the wallet is a Liquid one, which sets how often it is polled.
  final bool isLiquid;

  const TransactionSettlementTarget({
    required this.walletId,
    required this.txId,
    this.isLiquid = false,
  });

  @override
  bool operator ==(Object other) =>
      other is TransactionSettlementTarget &&
      other.walletId == walletId &&
      other.txId == txId &&
      other.isLiquid == isLiquid;

  @override
  int get hashCode => Object.hash(walletId, txId, isLiquid);
}

/// Whether an order swap pays out to a wallet of this app on an on-chain
/// network, so that the payout can be observed and confirmed.
bool orderSwapPayoutObservable(OrderSwapRecord record) =>
    record.destinationWalletId != null &&
    record.outNetwork != OrderSwapNetwork.lightning;

/// The payout transaction of an order swap, when the exchange reported it.
String? orderSwapPayoutTxId(OrderSwapRecord record) {
  final txId = record.transactionIdForNetwork(record.outNetwork);
  return txId == null || txId.isEmpty ? null : txId;
}

/// The settlement transaction of [transaction], in the same precedence the
/// status uses (order swap, Boltz swap, Payjoin, wallet transaction), or null
/// when nothing the app can observe settles it yet.
TransactionSettlementTarget? settlementTargetOf(Transaction? transaction) {
  if (transaction == null) return null;
  final orderSwap = transaction.orderSwap;
  if (orderSwap != null) {
    final walletId = orderSwap.destinationWalletId;
    final txId = orderSwapPayoutTxId(orderSwap);
    if (walletId == null ||
        txId == null ||
        !orderSwapPayoutObservable(orderSwap)) {
      return null;
    }
    return TransactionSettlementTarget(
      walletId: walletId,
      txId: txId,
      isLiquid: orderSwap.outNetwork == OrderSwapNetwork.liquid,
    );
  }
  final swap = transaction.swap;
  if (swap != null) {
    final (walletId, txId) = switch (swap) {
      LnReceiveSwap(:final receiveWalletId, :final receiveTxid) => (
        receiveWalletId,
        receiveTxid,
      ),
      ChainSwap(:final receiveWalletId, :final receiveTxid) => (
        receiveWalletId,
        receiveTxid,
      ),
      LnSendSwap() => (null, null),
    };
    if (walletId == null || txId == null || txId.isEmpty) return null;
    return TransactionSettlementTarget(
      walletId: walletId,
      txId: txId,
      isLiquid:
          swap.type == SwapType.bitcoinToLiquid ||
          swap.type == SwapType.lightningToLiquid,
    );
  }
  final payjoin = transaction.payjoin;
  if (payjoin != null) {
    final txId = switch (transaction.displayPayjoinStatus) {
      PayjoinStatus.completed => payjoin.txId,
      PayjoinStatus.aborted => payjoin.originalTxId,
      _ => null,
    };
    if (txId == null) return null;
    return TransactionSettlementTarget(walletId: payjoin.walletId, txId: txId);
  }
  final walletTransaction = transaction.walletTransaction;
  if (walletTransaction == null) return null;
  return TransactionSettlementTarget(
    walletId: walletTransaction.walletId,
    txId: walletTransaction.txId,
    isLiquid: walletTransaction.isLiquid,
  );
}
