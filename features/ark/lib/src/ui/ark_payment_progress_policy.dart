import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

/// Statuses of an Ark operation as Scuttle exposes them: created `pending`,
/// then completed. [steps] holds those two labels. [pendingState] is how the
/// pending status reads: a board's funding transaction is already on the
/// network while it is pending.
///
/// An unknown outcome is held at the first status, never failed.
BullPaymentProgress arkPaymentProgress(
  ArkOperationStatus? status, {
  required List<String> steps,
  BullPaymentStepState pendingState = BullPaymentStepState.active,
}) {
  assert(steps.length == 2);
  return switch (status) {
    ArkOperationStatus.succeeded => BullPaymentProgress(
      steps: steps,
      completed: 1,
    ),
    ArkOperationStatus.failed || ArkOperationStatus.conflicted =>
      BullPaymentProgress(steps: steps, completed: 1, failedAt: 1),
    ArkOperationStatus.outcomeUnknown => BullPaymentProgress(
      steps: steps,
      completed: 0,
      currentState: BullPaymentStepState.held,
    ),
    ArkOperationStatus.pending => BullPaymentProgress(
      steps: steps,
      completed: 0,
      currentState: pendingState,
    ),
    _ => BullPaymentProgress(steps: steps, completed: 0),
  };
}
