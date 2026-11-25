import 'package:bull_ui/bull_ui.dart';
import 'package:swaps/order_swaps.dart';

import '../domain/transaction_settlement.dart';
import 'send_payment_policy.dart';

/// Statuses of an exchange order swap seen from its record alone, as the
/// details screen holds it: [steps] has the four labels of [orderPaymentProgress]
/// or, when the payout lands in a wallet of this app
/// ([orderSwapPayoutObservable]), five: payin sending, payin broadcast,
/// payout in progress, payout broadcast, confirmed.
///
/// With an observable payout the last status is the wallet observing the payout
/// transaction as [confirmed], never the exchange's `completed`.
BullPaymentProgress orderSwapDetailsProgress({
  required List<String> steps,
  required OrderSwapRecord record,
  bool confirmed = false,
}) {
  final observable = orderSwapPayoutObservable(record);
  assert(steps.length == (observable ? 5 : 4));
  final status = record.localStatus;
  final underReview = record.order?.requiresManualReview ?? false;
  final base = orderPaymentProgress(
    steps: steps.sublist(0, 4),
    status: status,
    payinTxid: record.localPayinTransactionId,
    underReview: underReview,
  );
  if (!observable) return base;
  final payoutKnown = orderSwapPayoutTxId(record) != null;
  final paysOut =
      status == OrderSwapLocalStatus.payoutInProgress ||
      status == OrderSwapLocalStatus.completed;
  if (!paysOut) {
    return BullPaymentProgress(
      steps: steps,
      completed: base.completed,
      currentState: base.currentState,
      failedAt: base.failedAt,
      refund: base.refund,
    );
  }
  if (!payoutKnown) {
    return BullPaymentProgress(
      steps: steps,
      completed: 2,
      currentState: status == OrderSwapLocalStatus.completed
          ? BullPaymentStepState.held
          : BullPaymentStepState.active,
    );
  }
  // Only the exchange's completion lets the confirmation end the payment,
  // the same condition as [orderSwapDetailsPhase].
  return confirmed && status == OrderSwapLocalStatus.completed
      ? BullPaymentProgress(steps: steps, completed: steps.length)
      : BullPaymentProgress(
          steps: steps,
          completed: 3,
          currentState: BullPaymentStepState.broadcast,
        );
}

/// Success needs the confirmed payout when it is observable, else the
/// exchange's completion.
BullPaymentPhase orderSwapDetailsPhase({
  required OrderSwapRecord record,
  bool confirmed = false,
}) {
  final phase = orderPaymentPhase(
    record.localStatus,
    hasFundsMoved: record.hasFundsMoved,
  );
  if (phase == BullPaymentPhase.success && orderSwapPayoutObservable(record)) {
    return confirmed && orderSwapPayoutTxId(record) != null
        ? BullPaymentPhase.success
        : BullPaymentPhase.sending;
  }
  return phase ?? BullPaymentPhase.sending;
}
