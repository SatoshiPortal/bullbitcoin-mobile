import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_payment_progress_policy.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const steps = ['Pending', 'Completed'];

  test('a pending operation is in the first status', () {
    for (final status in [
      null,
      ArkOperationStatus.prepared,
      ArkOperationStatus.admitted,
      ArkOperationStatus.pending,
    ]) {
      final progress = arkPaymentProgress(status, steps: steps);
      expect(progress.completed, 0, reason: '$status');
      expect(progress.currentState, BullPaymentStepState.active);
      expect(progress.failedAt, isNull);
    }
  });

  test('only a succeeded operation reaches the last status', () {
    final progress = arkPaymentProgress(
      ArkOperationStatus.succeeded,
      steps: steps,
    );
    expect(progress.completed, 1);
    expect(progress.failedAt, isNull);
  });

  test('failed and conflicted operations fail at the completion', () {
    for (final status in [
      ArkOperationStatus.failed,
      ArkOperationStatus.conflicted,
    ]) {
      final progress = arkPaymentProgress(status, steps: steps);
      expect(progress.completed, 1);
      expect(progress.failedAt, 1);
    }
  });

  test('an unknown outcome is held, never failed', () {
    final progress = arkPaymentProgress(
      ArkOperationStatus.outcomeUnknown,
      steps: steps,
    );
    expect(progress.completed, 0);
    expect(progress.currentState, BullPaymentStepState.held);
    expect(progress.failedAt, isNull);
  });

  test('a board funding transaction is on the network while pending', () {
    expect(
      arkPaymentProgress(
        ArkOperationStatus.pending,
        steps: steps,
        pendingState: BullPaymentStepState.broadcast,
      ).currentState,
      BullPaymentStepState.broadcast,
    );
    expect(
      arkPaymentProgress(
        ArkOperationStatus.outcomeUnknown,
        steps: steps,
        pendingState: BullPaymentStepState.broadcast,
      ).currentState,
      BullPaymentStepState.held,
    );
  });
}
