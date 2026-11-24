import 'package:bull_ui/bull_ui.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';

/// A funding transaction is not evidence that the destination was paid.
bool swapTransitionSucceeded({
  required String swapId,
  required String? orderId,
  required ChainSwap? swap,
  required OrderSwapRecord? order,
}) {
  if (swap == null ||
      swap.id != swapId ||
      swap.status != SwapStatus.completed ||
      swap.refundTxid != null) {
    return false;
  }
  return orderId == null
      ? order == null && (swap.receiveTxid?.isNotEmpty ?? false)
      : order?.localId == orderId &&
            order?.localStatus == OrderSwapLocalStatus.completed;
}

bool swapFundingMayHaveMoved(
  ChainSwap swap,
  OrderSwapRecord? order, {
  String? fundingTxId,
}) =>
    (fundingTxId?.isNotEmpty ?? false) ||
    (swap.sendTxid?.isNotEmpty ?? false) ||
    (swap.pendingLockupTx?.isNotEmpty ?? false) ||
    (order?.localPayinTransactionId?.isNotEmpty ?? false) ||
    order?.localStatus == OrderSwapLocalStatus.broadcastUnknown ||
    order?.localStatus == OrderSwapLocalStatus.payinBroadcast ||
    order?.localStatus == OrderSwapLocalStatus.payoutInProgress;

BullPaymentPhase swapTransitionPhase({
  required String swapId,
  required String? orderId,
  required ChainSwap? swap,
  required OrderSwapRecord? order,
  String? fundingTxId,
}) {
  if (swap == null ||
      swap.id != swapId ||
      (orderId == null ? order != null : order?.localId != orderId)) {
    return BullPaymentPhase.sending;
  }
  if (swapTransitionSucceeded(
    swapId: swapId,
    orderId: orderId,
    swap: swap,
    order: order,
  )) {
    return BullPaymentPhase.success;
  }
  if (swap.refundTxid != null ||
      swap.status == SwapStatus.refunded ||
      order?.localStatus == OrderSwapLocalStatus.refunded) {
    return BullPaymentPhase.failed;
  }
  if ((swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) &&
      !swapFundingMayHaveMoved(swap, order, fundingTxId: fundingTxId)) {
    return BullPaymentPhase.failed;
  }
  return BullPaymentPhase.sending;
}
