import 'package:bull_ui/bull_ui.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinStatus;
import 'package:swaps/swaps.dart' show SwapStatus;

/// Statuses of an on-chain receive: payment detected (its transaction waits
/// for a confirmation), confirmed. [confirmed] comes from the wallet
/// observing the very transaction that was first detected.
BullPaymentProgress receiveOnchainProgress({
  required List<String> steps,
  required bool confirmed,
}) => BullPaymentProgress(
  steps: steps,
  completed: confirmed ? 1 : 0,
  currentState: confirmed
      ? BullPaymentStepState.active
      : BullPaymentStepState.broadcast,
);

BullPaymentPhase receiveOnchainPhase({required bool confirmed}) =>
    confirmed ? BullPaymentPhase.success : BullPaymentPhase.sending;

/// Statuses of a payjoin receive: original received, proposal sent, payment
/// detected (a transaction is on the network), confirmed.
///
/// An aborted session paid through the original transaction: the proposal is
/// skipped and the original is the detected payment. An expired session waits
/// on the manual fallback, so it is held where it stopped, never failed.
BullPaymentProgress receivePayjoinProgress({
  required List<String> steps,
  required PayjoinStatus status,
  required bool hasOriginal,
  required bool hasProposal,
  required bool confirmed,
}) {
  assert(steps.length == 4);
  final visible =
      status == PayjoinStatus.completed || status == PayjoinStatus.aborted;
  if (visible) {
    return BullPaymentProgress(
      steps: steps,
      completed: confirmed ? 3 : 2,
      currentState: confirmed
          ? BullPaymentStepState.active
          : BullPaymentStepState.broadcast,
      skippedAt: status == PayjoinStatus.aborted ? 1 : null,
    );
  }
  return BullPaymentProgress(
    steps: steps,
    completed: hasProposal || status == PayjoinStatus.proposed ? 1 : 0,
    currentState: status == PayjoinStatus.expired
        ? BullPaymentStepState.held
        : BullPaymentStepState.active,
  );
}

BullPaymentPhase receivePayjoinPhase({
  required PayjoinStatus status,
  required bool confirmed,
}) =>
    confirmed &&
        (status == PayjoinStatus.completed || status == PayjoinStatus.aborted)
    ? BullPaymentPhase.success
    : BullPaymentPhase.sending;

/// Statuses of a Lightning receive. A Boltz reverse swap goes through the
/// Boltz lockup and the claim broadcast, then it is complete; a direct
/// payment (paid straight to the chain address) is detected, then confirmed.
/// [steps] holds three labels for a swap and two for a direct payment.
///
/// A swap is complete once our claim is broadcast: the store then holds the
/// `receiveTxid` with the swap `completed`, and the payer's invoice is
/// settled. It does not wait for the claim's confirmation. A direct payment's
/// `receiveTxid` is only a candidate until the swap resolver accepts it by
/// setting the swap `completed`: it completes only when that holds and the
/// wallet observes the transaction as [confirmed].
BullPaymentProgress receiveLightningProgress({
  required List<String> steps,
  required SwapStatus status,
  required bool wasDirectPayment,
  required bool hasReceiveTxid,
  required bool confirmed,
}) {
  assert(steps.length == (wasDirectPayment ? 2 : 3));
  if (wasDirectPayment) {
    final settled = confirmed && status == SwapStatus.completed;
    return BullPaymentProgress(
      steps: steps,
      completed: settled ? 1 : 0,
      currentState: settled
          ? BullPaymentStepState.active
          : BullPaymentStepState.broadcast,
    );
  }
  if (status.hasFailed && !hasReceiveTxid) {
    return BullPaymentProgress(steps: steps, completed: 0, failedAt: 0);
  }
  final claimed = _reverseSwapClaimed(
    status: status,
    hasReceiveTxid: hasReceiveTxid,
    confirmed: confirmed,
  );
  final claimBroadcast = hasReceiveTxid || status == SwapStatus.completed;
  final held =
      status.hasFailed ||
      status == SwapStatus.canCoop ||
      status == SwapStatus.refundable;
  return BullPaymentProgress(
    steps: steps,
    completed: claimed
        ? 2
        : claimBroadcast
        ? 1
        : 0,
    currentState: claimed
        ? BullPaymentStepState.active
        : held
        ? BullPaymentStepState.held
        : claimBroadcast
        ? BullPaymentStepState.broadcast
        : BullPaymentStepState.active,
  );
}

bool _reverseSwapClaimed({
  required SwapStatus status,
  required bool hasReceiveTxid,
  required bool confirmed,
}) => hasReceiveTxid && (confirmed || status == SwapStatus.completed);

BullPaymentPhase receiveLightningPhase({
  required SwapStatus status,
  required bool wasDirectPayment,
  required bool hasReceiveTxid,
  required bool confirmed,
}) {
  if (wasDirectPayment) {
    return confirmed && status == SwapStatus.completed
        ? BullPaymentPhase.success
        : BullPaymentPhase.sending;
  }
  if (_reverseSwapClaimed(
    status: status,
    hasReceiveTxid: hasReceiveTxid,
    confirmed: confirmed,
  )) {
    return BullPaymentPhase.success;
  }
  if (!wasDirectPayment && status.hasFailed && !hasReceiveTxid) {
    return BullPaymentPhase.failed;
  }
  return BullPaymentPhase.sending;
}
