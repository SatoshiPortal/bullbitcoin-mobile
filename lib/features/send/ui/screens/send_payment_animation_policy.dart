import 'package:bull_ui/bull_ui.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';

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

BullPaymentPhase? boltzPaymentPhase(
  SwapStatus status, {
  required bool refunded,
  required bool completedProven,
}) {
  if (refunded) return BullPaymentPhase.failed;
  return switch (status) {
    SwapStatus.completed when completedProven => BullPaymentPhase.success,
    SwapStatus.refunded => BullPaymentPhase.failed,
    _ => null,
  };
}

bool directPaymentSucceeded({
  required bool expectsSwap,
  required String? previousTxId,
  required String? transactionId,
  required bool hasPayjoin,
}) =>
    !expectsSwap &&
    previousTxId == null &&
    transactionId != null &&
    !hasPayjoin;
