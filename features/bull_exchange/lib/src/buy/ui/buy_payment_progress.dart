import 'package:bull_exchange/src/buy/presentation/buy_flow.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// The network a buy pays out over.
BullPaymentNetwork buyPaymentNetwork(BuyOrder order) =>
    switch (order.payoutMethod) {
      OrderPaymentMethod.liquid => BullPaymentNetwork.liquid,
      OrderPaymentMethod.lnAddress ||
      OrderPaymentMethod.lnInvoice ||
      OrderPaymentMethod.lnUrl => BullPaymentNetwork.lightning,
      _ => BullPaymentNetwork.bitcoin,
    };

bool _isLightning(BuyOrder order) =>
    buyPaymentNetwork(order) == BullPaymentNetwork.lightning;

/// The watch no longer follows the payout live: its outcome is unknown.
bool _watchHeld(OutcomeWatchState<BuyOrder> watch) => switch (watch) {
  WatchPaused() || WatchUnreadable() || WatchTimedOut() => true,
  WatchWatching() ||
  WatchDone() ||
  WatchReceipt() ||
  WatchFailed() ||
  WatchSessionEnded() ||
  WatchLeft() => false,
};

/// An on-chain payout is proven only by the exchange's completed status
/// together with the transaction it sent: this app cannot observe that
/// transaction in the destination wallet, so there is no confirmed status.
bool _delivered(BuyOrder order) =>
    order.payoutStatus == OrderPayoutStatus.completed &&
    (_isLightning(order) || order.transactionId != null);

/// The payout stopped with nothing in flight. A transaction already sent keeps
/// the payment open: it can still reach its destination.
bool _stopped(BuyOrder order, OutcomeWatchState<BuyOrder> watch) =>
    !_delivered(order) &&
    order.transactionId == null &&
    (watch is WatchFailed || buyPayoutVerdict(order) == OutcomeVerdict.failed);

/// Index of the status the payout is in.
int _reached(BuyOrder order) {
  if (_isLightning(order)) {
    return switch (order.payoutStatus) {
      OrderPayoutStatus.completed => 2,
      OrderPayoutStatus.inProgress || OrderPayoutStatus.awaitingClaim => 1,
      OrderPayoutStatus.notStarted ||
      OrderPayoutStatus.scheduled ||
      OrderPayoutStatus.canceled ||
      OrderPayoutStatus.failed ||
      OrderPayoutStatus.unknown => 0,
    };
  }
  if (order.transactionId != null) {
    return order.payoutStatus == OrderPayoutStatus.completed ? 3 : 2;
  }
  return switch (order.payoutStatus) {
    OrderPayoutStatus.inProgress || OrderPayoutStatus.awaitingClaim => 1,
    // Completed without a transaction: the exchange says it paid but nothing
    // proves it, so the payout stays in progress.
    OrderPayoutStatus.completed => 1,
    OrderPayoutStatus.notStarted ||
    OrderPayoutStatus.scheduled ||
    OrderPayoutStatus.canceled ||
    OrderPayoutStatus.failed ||
    OrderPayoutStatus.unknown => 0,
  };
}

/// Statuses of a buy payout, in order. On-chain (4): order placed, payout in
/// progress, payout broadcast (waiting for its confirmation), payout sent.
/// Lightning (3): order placed, payout in progress, paid. [steps] holds the
/// labels of the order's own payout kind.
BullPaymentProgress buyPaymentProgress({
  required List<String> steps,
  required BuyOrder order,
  required OutcomeWatchState<BuyOrder> watch,
}) {
  assert(steps.length == (_isLightning(order) ? 3 : 4));
  if (_delivered(order)) {
    return BullPaymentProgress(steps: steps, completed: steps.length);
  }
  final reached = _reached(order);
  if (_stopped(order, watch)) {
    final failedAt = (reached + 1).clamp(0, steps.length - 1);
    return BullPaymentProgress(
      steps: steps,
      completed: failedAt,
      failedAt: failedAt,
    );
  }
  return BullPaymentProgress(
    steps: steps,
    completed: reached,
    currentState: _watchHeld(watch)
        ? BullPaymentStepState.held
        : !_isLightning(order) && reached == 2
        ? BullPaymentStepState.broadcast
        : BullPaymentStepState.active,
  );
}

BullPaymentPhase buyPaymentPhase({
  required BuyOrder order,
  required OutcomeWatchState<BuyOrder> watch,
}) {
  if (_delivered(order)) return BullPaymentPhase.success;
  if (_stopped(order, watch)) return BullPaymentPhase.failed;
  return BullPaymentPhase.sending;
}
