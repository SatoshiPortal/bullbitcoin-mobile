import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_exit_animation_policy.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  const steps = ['Unrolling', 'Delay', 'Claimable', 'Broadcast', 'Confirmed'];
  ArkExit exit(ArkExitStatus status, {int? height, String? txid}) => ArkExit(
    id: 'exit',
    amount: Sats.fromInt(1234),
    status: status,
    claimableHeight: height,
    claimTxid: txid,
  );
  BullPaymentProgress? progress(
    ArkExitStatus status, {
    int? height,
    String? txid,
  }) => arkExitAnimationProgress(
    exit(status, height: height, txid: txid),
    steps: steps,
  );

  test('phase reflects observed exit status only', () {
    for (final status in ArkExitStatus.values) {
      expect(arkExitAnimationPhase(status), switch (status) {
        ArkExitStatus.unknown || ArkExitStatus.none => null,
        ArkExitStatus.failed => BullPaymentPhase.failed,
        ArkExitStatus.claimed => BullPaymentPhase.success,
        _ => BullPaymentPhase.sending,
      }, reason: status.name);
    }
  });

  test('each observed exit status is one progress status', () {
    expect(progress(ArkExitStatus.unknown), isNull);
    expect(progress(ArkExitStatus.none), isNull);
    expect(progress(ArkExitStatus.pending)?.completed, 0);
    expect(progress(ArkExitStatus.pending, height: 100)?.completed, 1);
    expect(progress(ArkExitStatus.claimable, height: 100)?.completed, 2);
    final submitted = progress(ArkExitStatus.submitted, height: 100);
    expect(submitted?.completed, 3);
    expect(submitted?.currentState, BullPaymentStepState.broadcast);
    expect(progress(ArkExitStatus.claimed, height: 100)?.completed, 4);
  });

  test('no status invents a delay fraction or a failure', () {
    for (final status in ArkExitStatus.values.where(
      (status) => status != ArkExitStatus.failed,
    )) {
      final result = progress(status, height: 100);
      expect(result?.currentFraction, isNull, reason: status.name);
      expect(result?.failedAt, isNull, reason: status.name);
    }
  });

  test('a failed exit stops at the first status it never reached', () {
    expect(progress(ArkExitStatus.failed)?.failedAt, 1);
    expect(progress(ArkExitStatus.failed, height: 100)?.failedAt, 2);
    expect(
      progress(ArkExitStatus.failed, height: 100, txid: 'claim')?.failedAt,
      4,
    );
    expect(progress(ArkExitStatus.failed)?.completed, 1);
  });
}
