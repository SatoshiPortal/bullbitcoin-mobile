import 'package:bull_ui/bull_ui.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinStatus;

/// Statuses of an exchange order: payin (preparing, then broadcast), payout in
/// progress, completed. [steps] holds their four labels in that order.
///
/// An unknown broadcast outcome and a payin under review are held, not failed.
/// A failed or expired order whose payin moved funds waits for its refund and
/// stays held at the status it reached; only a refund broadcast, or a failure
/// before any funds moved, stops the payment.
BullPaymentProgress orderPaymentProgress({
  required List<String> steps,
  required OrderSwapLocalStatus? status,
  String? payinTxid,
  bool underReview = false,
}) {
  assert(steps.length == 4);
  final fundsMoved = payinTxid?.isNotEmpty ?? false;
  final reached = switch (status) {
    OrderSwapLocalStatus.payinBroadcast => 1,
    OrderSwapLocalStatus.payoutInProgress => 2,
    OrderSwapLocalStatus.completed => 3,
    OrderSwapLocalStatus.refunded ||
    OrderSwapLocalStatus.failed ||
    OrderSwapLocalStatus.expired => fundsMoved ? 1 : 0,
    _ => 0,
  };
  switch (status) {
    case OrderSwapLocalStatus.refunded:
      return BullPaymentProgress(
        steps: steps,
        completed: reached + 1,
        failedAt: reached + 1,
        refund: BullPaymentRefund.done,
      );
    case OrderSwapLocalStatus.failed || OrderSwapLocalStatus.expired
        when !fundsMoved:
      return BullPaymentProgress(steps: steps, completed: 1, failedAt: 1);
    case OrderSwapLocalStatus.failed || OrderSwapLocalStatus.expired:
      return BullPaymentProgress(
        steps: steps,
        completed: reached,
        currentState: BullPaymentStepState.held,
      );
    case OrderSwapLocalStatus.broadcastUnknown:
      return BullPaymentProgress(
        steps: steps,
        completed: 0,
        currentState: BullPaymentStepState.held,
      );
    case OrderSwapLocalStatus.payinBroadcast:
      return BullPaymentProgress(
        steps: steps,
        completed: 1,
        currentState: underReview
            ? BullPaymentStepState.held
            : BullPaymentStepState.broadcast,
      );
    default:
      return BullPaymentProgress(steps: steps, completed: reached);
  }
}

/// Statuses of a direct on-chain send: signing, broadcast (waiting for its
/// confirmation), confirmed. [steps] holds their three labels in that order.
///
/// The payment is complete only once the confirmation is observed, which the
/// caller reports through the success phase.
BullPaymentProgress directPaymentProgress({
  required List<String> steps,
  required bool broadcast,
  required bool failed,
}) {
  assert(steps.length == 3);
  // A failure here is always before the broadcast: signing is behind, the
  // broadcast status was never reached.
  if (failed && !broadcast) {
    return BullPaymentProgress(steps: steps, completed: 1, failedAt: 1);
  }
  return BullPaymentProgress(
    steps: steps,
    completed: broadcast ? 1 : 0,
    currentState: broadcast
        ? BullPaymentStepState.broadcast
        : BullPaymentStepState.active,
  );
}

bool _boltzRefunded(Swap swap) =>
    (switch (swap) {
      LnSendSwap(:final refundTxid) ||
      ChainSwap(:final refundTxid) => refundTxid != null,
      _ => false,
    }) ||
    swap.status == SwapStatus.refunded;

/// Whether the lockup of this send swap left the wallet.
bool _boltzLockedUp(Swap swap) {
  final (sendTxid, refundTxid) = switch (swap) {
    LnSendSwap(:final sendTxid, :final refundTxid) ||
    ChainSwap(:final sendTxid, :final refundTxid) => (sendTxid, refundTxid),
    _ => (null, null),
  };
  return (sendTxid?.isNotEmpty ?? false) ||
      refundTxid != null ||
      swap.status == SwapStatus.paid ||
      swap.status == SwapStatus.claimable ||
      swap.status == SwapStatus.canCoop ||
      swap.status == SwapStatus.completed ||
      swap.status == SwapStatus.refundable ||
      swap.status == SwapStatus.refunded;
}

/// Statuses of a Boltz send swap, four labels in this order.
///
/// Submarine (Lightning) swap: sending lockup, lockup sent, invoice paid,
/// completed. Chain swap: sending lockup, lockup sent, claimable (Boltz
/// locked), claim broadcast. A send-flow chain swap pays an external address
/// this app cannot watch, so it ends at the claim broadcast, not at a
/// confirmation.
///
/// Funds that moved and are not refunded yet keep the payment sending with the
/// refund available; a broadcast refund, or a failure before any funds moved,
/// stops it.
BullPaymentProgress boltzPaymentProgress({
  required List<String> steps,
  required Swap? swap,
}) {
  assert(steps.length == 4);
  if (swap == null) return BullPaymentProgress(steps: steps, completed: 0);
  final status = swap.status;
  final refunded = _boltzRefunded(swap);
  final lockedUp = _boltzLockedUp(swap);
  final reached = !lockedUp
      ? 0
      : switch (swap) {
          LnSendSwap(:final completionTime) =>
            status == SwapStatus.completed && !refunded
                ? 3
                : status == SwapStatus.canCoop ||
                      (status == SwapStatus.paid && completionTime != null)
                ? 2
                : 1,
          ChainSwap(:final receiveTxid) =>
            receiveTxid?.isNotEmpty ?? false
                ? 3
                : status == SwapStatus.claimable ||
                      status == SwapStatus.completed
                ? 2
                : 1,
          _ => 0,
        };
  final stopped =
      refunded ||
      status == SwapStatus.refundable ||
      status == SwapStatus.failed ||
      status == SwapStatus.expired;
  if (!stopped) {
    return BullPaymentProgress(
      steps: steps,
      completed: reached,
      currentState: swap is ChainSwap && reached == 3
          ? BullPaymentStepState.broadcast
          : BullPaymentStepState.active,
    );
  }
  final neverReached = (reached + 1).clamp(0, 3);
  if (refunded) {
    return BullPaymentProgress(
      steps: steps,
      completed: neverReached,
      failedAt: neverReached,
      refund: BullPaymentRefund.done,
    );
  }
  if (!lockedUp && !swap.hasPendingLockup) {
    return BullPaymentProgress(steps: steps, completed: 1, failedAt: 1);
  }
  return BullPaymentProgress(
    steps: steps,
    completed: reached,
    failedAt: neverReached,
    refund: BullPaymentRefund.available,
  );
}

/// Statuses of a Payjoin send: requested, proposed, broadcasted, confirmed.
/// [steps] holds their four labels in that order.
///
/// An aborted session sent the original transaction instead: the proposal is
/// skipped and the payment waits for that transaction's confirmation. A paused
/// session, or one that expired while the original may still land, is held at
/// the status it reached.
BullPaymentProgress payjoinPaymentProgress({
  required List<String> steps,
  required PayjoinStatus? status,
  int previousCompleted = 0,
  bool paused = false,
  bool expiredWithoutBroadcast = false,
}) {
  assert(steps.length == 4);
  final held = paused ? BullPaymentStepState.held : BullPaymentStepState.active;
  return switch (status) {
    // A retained sender is also "requested" when its POST failed or its
    // outcome is unknown. Only a proposal proves the request was delivered.
    PayjoinStatus.proposed => BullPaymentProgress(
      steps: steps,
      completed: 1,
      currentState: held,
    ),
    PayjoinStatus.completed => BullPaymentProgress(
      steps: steps,
      completed: 2,
      currentState: BullPaymentStepState.broadcast,
    ),
    PayjoinStatus.aborted => BullPaymentProgress(
      steps: steps,
      completed: 2,
      currentState: BullPaymentStepState.broadcast,
      skippedAt: 1,
    ),
    PayjoinStatus.expired when expiredWithoutBroadcast => BullPaymentProgress(
      steps: steps,
      completed: 1,
      failedAt: 1,
    ),
    PayjoinStatus.expired => BullPaymentProgress(
      steps: steps,
      completed: previousCompleted.clamp(0, 1),
      currentState: BullPaymentStepState.held,
    ),
    _ => BullPaymentProgress(steps: steps, completed: 0, currentState: held),
  };
}

/// A settled Payjoin succeeds once the wallet observes the settled transaction
/// (the payjoin, or the original after an abort) as confirmed: [confirmed].
BullPaymentPhase payjoinPaymentPhase(
  PayjoinStatus? status, {
  bool expiredWithoutBroadcast = false,
  bool confirmed = false,
}) => switch (status) {
  PayjoinStatus.completed ||
  PayjoinStatus.aborted when confirmed => BullPaymentPhase.success,
  PayjoinStatus.expired when expiredWithoutBroadcast => BullPaymentPhase.failed,
  _ => BullPaymentPhase.sending,
};

BullPaymentPhase? orderPaymentPhase(
  OrderSwapLocalStatus status, {
  required bool hasFundsMoved,
}) => switch (status) {
  OrderSwapLocalStatus.completed => BullPaymentPhase.success,
  OrderSwapLocalStatus.refunded => BullPaymentPhase.failed,
  OrderSwapLocalStatus.failed ||
  OrderSwapLocalStatus.expired when !hasFundsMoved => BullPaymentPhase.failed,
  _ => null,
};

/// Success needs the proof of the last status: the paid invoice for a
/// submarine swap, the claim transaction for a chain swap. A swap that failed
/// before its lockup left holds nothing to refund and is over.
BullPaymentPhase? boltzPaymentPhase(Swap swap) {
  if (_boltzRefunded(swap)) return BullPaymentPhase.failed;
  final status = swap.status;
  final completedProven = switch (swap) {
    ChainSwap(:final receiveTxid) => receiveTxid?.isNotEmpty ?? false,
    LnSendSwap() => true,
    _ => false,
  };
  if (status == SwapStatus.completed && completedProven) {
    return BullPaymentPhase.success;
  }
  if ((status == SwapStatus.failed || status == SwapStatus.expired) &&
      !_boltzLockedUp(swap) &&
      !swap.hasPendingLockup) {
    return BullPaymentPhase.failed;
  }
  return null;
}

/// Whether this confirmation's direct send reached the network.
bool directPaymentBroadcast({
  required bool expectsSwap,
  required String? previousTxId,
  required String? transactionId,
  required bool hasPayjoin,
}) =>
    !expectsSwap &&
    previousTxId == null &&
    transactionId != null &&
    !hasPayjoin;

/// A direct send succeeds once the wallet observes its own transaction as
/// confirmed. A txid alone only proves the broadcast.
bool directPaymentSucceeded({
  required bool broadcast,
  required String? transactionId,
  required String? observedTransactionId,
  required bool observedConfirmed,
}) =>
    broadcast &&
    transactionId != null &&
    observedTransactionId == transactionId &&
    observedConfirmed;
