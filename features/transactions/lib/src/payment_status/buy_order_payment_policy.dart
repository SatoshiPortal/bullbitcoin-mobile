import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';

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

/// The payout is delivered once the exchange reports it completed. This app
/// cannot observe the payout in the destination wallet, so there is no
/// confirmed status.
bool _delivered(BuyOrder order) =>
    order.payoutStatus == OrderPayoutStatus.completed;

/// The order or its payout ended without completing.
bool _ended(BuyOrder order) {
  final orderEnded = switch (order.orderStatus) {
    OrderStatus.canceled ||
    OrderStatus.expired ||
    OrderStatus.orderExpired ||
    OrderStatus.rejected ||
    OrderStatus.failed => true,
    OrderStatus.inProgress ||
    OrderStatus.awaitingConfirmation ||
    OrderStatus.completed ||
    OrderStatus.unknown => false,
  };
  return orderEnded || order.payoutStatus.isTerminal;
}

/// The payout stopped with nothing in flight. A transaction already sent keeps
/// the payment open: it can still reach its destination. [failed] forces the
/// stop when the caller knows the order failed from elsewhere.
bool _stopped(BuyOrder order, {required bool failed}) =>
    !_delivered(order) &&
    order.transactionId == null &&
    (failed || _ended(order));

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
    OrderPayoutStatus.completed => 3,
    OrderPayoutStatus.notStarted ||
    OrderPayoutStatus.scheduled ||
    OrderPayoutStatus.canceled ||
    OrderPayoutStatus.failed ||
    OrderPayoutStatus.unknown => 0,
  };
}

/// Statuses of a buy payout, in order, computed from the order alone.
/// On-chain (4): order placed, payout in progress, payout broadcast (waiting
/// for its confirmation), payout sent. Lightning (3): order placed, payout in
/// progress, paid. [steps] holds the labels of the order's own payout kind.
///
/// [held] marks the payout as no longer followed live (outcome unknown);
/// [failed] forces a stop the order alone does not show.
BullPaymentProgress buyOrderPaymentProgress({
  required List<String> steps,
  required BuyOrder order,
  bool held = false,
  bool failed = false,
}) {
  assert(steps.length == (_isLightning(order) ? 3 : 4));
  if (_delivered(order)) {
    return BullPaymentProgress(steps: steps, completed: steps.length);
  }
  final reached = _reached(order);
  if (_stopped(order, failed: failed)) {
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
    currentState: held
        ? BullPaymentStepState.held
        : !_isLightning(order) && reached == 2
        ? BullPaymentStepState.broadcast
        : BullPaymentStepState.active,
  );
}

BullPaymentPhase buyOrderPaymentPhase(BuyOrder order, {bool failed = false}) {
  if (_delivered(order)) return BullPaymentPhase.success;
  if (_stopped(order, failed: failed)) return BullPaymentPhase.failed;
  return BullPaymentPhase.sending;
}
