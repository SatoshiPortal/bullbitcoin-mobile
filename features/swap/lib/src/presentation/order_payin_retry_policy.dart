import 'package:spend/spend.dart';
import 'package:swaps/order_swaps.dart';

/// Ephemeral evidence only: a durable unknown status is not proof of rejection.
final class RejectedOrderPayin {
  final String orderId;
  final String signedPayin;

  const RejectedOrderPayin(this.orderId, this.signedPayin);

  static RejectedOrderPayin? fromFirstAttempt(
    OrderSwapRecord before,
    SpendFailure failure,
  ) {
    final signed = before.signedPayinTransaction;
    if (failure is! SpendBroadcastRejectedFailure ||
        before.localStatus != OrderSwapLocalStatus.readyToBroadcast ||
        before.hasFundsMoved ||
        signed == null) {
      return null;
    }
    return RejectedOrderPayin(before.localId, signed);
  }

  bool allows(OrderSwapRecord? record) {
    if (record == null ||
        record.localId != orderId ||
        record.localStatus != OrderSwapLocalStatus.broadcastUnknown ||
        record.hasFundsMoved ||
        record.signedPayinTransaction != signedPayin) {
      return false;
    }
    final order = record.order;
    if (order == null ||
        !order.confirmationDeadline.isAfter(DateTime.now()) ||
        !const {
          'awaiting payment',
          'pending',
        }.contains(order.payinStatus.trim().toLowerCase()) ||
        order.transactionIdForPayin(record.inNetwork) != null) {
      return false;
    }
    final status = order.orderStatus.trim().toLowerCase();
    final payout = order.payoutStatus.trim().toLowerCase();
    const stopped = {
      'completed',
      'refunded',
      'expired',
      'payment deadline expired',
      'failed',
      'rejected',
      'cancelled',
      'canceled',
    };
    return !stopped.contains(status) && !stopped.contains(payout);
  }
}

extension on OrderSwap {
  String? transactionIdForPayin(OrderSwapNetwork network) => switch (network) {
    OrderSwapNetwork.bitcoin => bitcoinTransactionId,
    OrderSwapNetwork.liquid => liquidTransactionId,
    OrderSwapNetwork.lightning => null,
  };
}
