import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

BullPaymentPhase? arkExitAnimationPhase(ArkExitStatus status) =>
    switch (status) {
      ArkExitStatus.unknown || ArkExitStatus.none => null,
      ArkExitStatus.failed => BullPaymentPhase.failed,
      ArkExitStatus.claimed => BullPaymentPhase.success,
      _ => BullPaymentPhase.sending,
    };

/// Statuses of a unilateral exit: unrolling, exit delay, claimable, claim
/// broadcast, confirmed. [steps] holds those five labels in that order.
///
/// Bark knows the claimable height only once every exit transaction has
/// confirmed, so a pending exit with one is in its delay. No total delay is
/// exposed, so the delay has no fraction. A failed exit stops at the first
/// status it never reached, deduced from what the exit still carries.
BullPaymentProgress? arkExitAnimationProgress(
  ArkExit exit, {
  required List<String> steps,
}) {
  assert(steps.length == 5);
  if (exit.status == ArkExitStatus.failed) {
    final reached = (exit.claimTxid?.isNotEmpty ?? false)
        ? 3
        : exit.claimableHeight != null
        ? 1
        : 0;
    return BullPaymentProgress(
      steps: steps,
      completed: reached + 1,
      failedAt: reached + 1,
    );
  }
  return switch (exit.status) {
    ArkExitStatus.pending => BullPaymentProgress(
      steps: steps,
      completed: exit.claimableHeight == null ? 0 : 1,
    ),
    ArkExitStatus.claimable => BullPaymentProgress(steps: steps, completed: 2),
    ArkExitStatus.submitted => BullPaymentProgress(
      steps: steps,
      completed: 3,
      currentState: BullPaymentStepState.broadcast,
    ),
    ArkExitStatus.claimed => BullPaymentProgress(steps: steps, completed: 4),
    _ => null,
  };
}
