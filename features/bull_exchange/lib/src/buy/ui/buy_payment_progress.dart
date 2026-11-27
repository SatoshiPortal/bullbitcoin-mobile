import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:transactions/payment_status.dart';

export 'package:transactions/payment_status.dart' show buyPaymentNetwork;

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

bool _failed(BuyOrder order, OutcomeWatchState<BuyOrder> watch) =>
    watch is WatchFailed || buyPayoutVerdict(order) == OutcomeVerdict.failed;

/// Statuses of a buy payout: the order's own ([buyOrderPaymentProgress]) with
/// the payout watch applied on top.
BullPaymentProgress buyPaymentProgress({
  required List<String> steps,
  required BuyOrder order,
  required OutcomeWatchState<BuyOrder> watch,
}) => buyOrderPaymentProgress(
  steps: steps,
  order: order,
  held: _watchHeld(watch),
  failed: _failed(order, watch),
);

BullPaymentPhase buyPaymentPhase({
  required BuyOrder order,
  required OutcomeWatchState<BuyOrder> watch,
}) => buyOrderPaymentPhase(order, failed: _failed(order, watch));
