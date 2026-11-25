import 'package:bull_ui/bull_ui.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:transactions/transactions.dart' show WalletTransaction;

/// Whether the swap pays a wallet of this app. Only then can the app observe
/// the confirmation of the transaction that lands there, which makes
/// "Confirmed" the last status; otherwise the last status is the last one the
/// protocol proves.
bool swapReceiveObservable(ChainSwap? swap) => swap?.receiveWalletId != null;

bool _receiveConfirmed(ChainSwap swap, WalletTransaction? transaction) {
  final txId = swap.receiveTxid;
  return txId != null &&
      txId.isNotEmpty &&
      transaction != null &&
      transaction.txId == txId &&
      transaction.isConfirmed;
}

/// Statuses of a Boltz chain swap: sending the lockup, lockup sent, claimable,
/// claim broadcast and, when the receiving wallet is observable, confirmed.
/// [steps] holds four labels, or five when [swapReceiveObservable].
///
/// Boltz writes `completed` when the claim is broadcast: it is not a
/// confirmation.
int _boltzStatusIndex(ChainSwap swap) {
  final status = swap.status;
  if (swap.receiveTxid?.isNotEmpty ?? false) return 3;
  if (status == SwapStatus.claimable || status == SwapStatus.completed) {
    return 2;
  }
  final lockup =
      (swap.sendTxid?.isNotEmpty ?? false) ||
      status == SwapStatus.paid ||
      status == SwapStatus.canCoop ||
      status == SwapStatus.refundable ||
      status == SwapStatus.refunded ||
      (swap.refundTxid?.isNotEmpty ?? false);
  return lockup ? 1 : 0;
}

/// Statuses of an Exchange order swap: sending the payin, payin broadcast,
/// payout in progress and, when the payout transaction can be watched in the
/// receiving wallet, payout broadcast then confirmed (otherwise completed).
int _orderStatusIndex(
  OrderSwapRecord order,
  ChainSwap swap, {
  required bool observable,
}) {
  final payout = swap.receiveTxid?.isNotEmpty ?? false;
  return switch (order.localStatus) {
    OrderSwapLocalStatus.broadcastUnknown => 0,
    OrderSwapLocalStatus.payinBroadcast => 1,
    OrderSwapLocalStatus.payoutInProgress ||
    OrderSwapLocalStatus.completed => observable && payout ? 3 : 2,
    _ =>
      payout && observable
          ? 3
          : (order.localPayinTransactionId?.isNotEmpty ?? false)
          ? 1
          : 0,
  };
}

BullPaymentProgress swapTransitionProgress({
  required String swapId,
  required String? orderId,
  required ChainSwap? swap,
  required OrderSwapRecord? order,
  required List<String> steps,
  String? fundingTxId,
  WalletTransaction? receiveTransaction,
}) {
  final phase = swapTransitionPhase(
    swapId: swapId,
    orderId: orderId,
    swap: swap,
    order: order,
    fundingTxId: fundingTxId,
    receiveTransaction: receiveTransaction,
  );
  final matches =
      swap != null &&
      swap.id == swapId &&
      (orderId == null ? order == null : order?.localId == orderId);
  if (!matches) return BullPaymentProgress(steps: steps, completed: 0);
  final observable = swapReceiveObservable(swap);
  assert(steps.length == (observable ? 5 : 4));
  final last = steps.length - 1;
  if (phase == BullPaymentPhase.success) {
    return BullPaymentProgress(steps: steps, completed: last);
  }
  final reached = order == null
      ? _boltzStatusIndex(swap)
      : _orderStatusIndex(order, swap, observable: observable);
  final refundDone =
      swap.refundTxid != null ||
      swap.status == SwapStatus.refunded ||
      order?.localStatus == OrderSwapLocalStatus.refunded;
  final refundAvailable =
      !refundDone && order == null && swap.status == SwapStatus.refundable;
  if (phase == BullPaymentPhase.failed || refundAvailable) {
    final failedAt = (reached + 1).clamp(0, last);
    return BullPaymentProgress(
      steps: steps,
      completed: failedAt,
      failedAt: failedAt,
      refund: refundDone
          ? BullPaymentRefund.done
          : refundAvailable
          ? BullPaymentRefund.available
          : null,
    );
  }
  final held =
      swap.status == SwapStatus.failed ||
      swap.status == SwapStatus.expired ||
      order?.localStatus == OrderSwapLocalStatus.broadcastUnknown ||
      (order?.localStatus == OrderSwapLocalStatus.completed && reached == 2) ||
      order?.order?.requiresManualReview == true;
  // A Boltz lockup that is `paid` may be in the mempool or already confirmed:
  // only an order's payin and the final claim or payout are known broadcasts.
  final broadcast = reached == 3 || (reached == 1 && orderId != null);
  return BullPaymentProgress(
    steps: steps,
    completed: reached,
    currentState: held
        ? BullPaymentStepState.held
        : broadcast
        ? BullPaymentStepState.broadcast
        : BullPaymentStepState.active,
  );
}

/// A funding transaction is not evidence that the destination was paid. When
/// the receiving wallet belongs to this app, the swap succeeds once that
/// wallet observes the claim or payout transaction as confirmed.
bool swapTransitionSucceeded({
  required String swapId,
  required String? orderId,
  required ChainSwap? swap,
  required OrderSwapRecord? order,
  WalletTransaction? receiveTransaction,
}) {
  if (swap == null ||
      swap.id != swapId ||
      swap.status != SwapStatus.completed ||
      swap.refundTxid != null) {
    return false;
  }
  if (orderId == null
      ? order != null || !(swap.receiveTxid?.isNotEmpty ?? false)
      : order?.localId != orderId ||
            order?.localStatus != OrderSwapLocalStatus.completed) {
    return false;
  }
  return !swapReceiveObservable(swap) ||
      _receiveConfirmed(swap, receiveTransaction);
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
  WalletTransaction? receiveTransaction,
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
    receiveTransaction: receiveTransaction,
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
