import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_usecase.dart';
import 'package:bull_ark/src/domain/usecases/run_ark_background_usecase.dart';
import 'package:bull_ark/src/domain/usecases/update_ark_expiry_warning_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'ark_operations_test.dart' show account;
import 'ark_expiry_warning_test.dart' show observed, vtxo, Reminders;
import 'fake_ark_client.dart';

void main() {
  test('renewal pass preserves exact account and requires current successful VTXO stage', () async {
    final client = FakeArkClient()
      ..pass = Ok(
        ArkPassOutcome(
          snapshot: observed(vtxos: [vtxo('live', 500)]),
          completedStages: {ArkStage.vtxos},
        ),
      );
    final reminders = Reminders();
    expect(
      await RunArkBackgroundUsecase(
        SynchronizeArkUsecase(ArkRepositoryImpl(client)),
        UpdateArkExpiryWarningUsecase(reminders),
      ).execute(account()),
      isA<Ok>(),
    );
    expect(client.calls, ['renew']);
    expect(client.arguments, [(account(), true)]);
    expect(reminders.calls.length, 1);
  });
  for (final failed in [false, true]) {
    test(
      'no fresh VTXO evidence never changes alarms, failed=$failed',
      () async {
        final client = FakeArkClient()
          ..pass = Ok(
            ArkPassOutcome(
              snapshot: observed(vtxos: [vtxo('cached', 500)]),
              completedStages: failed ? {ArkStage.vtxos} : {},
              failedStageKinds: failed ? {ArkStage.vtxos} : {},
            ),
          );
        final reminders = Reminders();
        expect(
          await RunArkBackgroundUsecase(
            SynchronizeArkUsecase(ArkRepositoryImpl(client)),
            UpdateArkExpiryWarningUsecase(reminders),
          ).execute(account()),
          isA<Err>(),
        );
        expect(reminders.calls, isEmpty);
        expect(client.calls, ['renew']);
      },
    );
  }
  test(
    'delegated renewal final stale snapshot never cancels retained reminder',
    () async {
      final client = FakeArkClient()
        ..pass = Ok(
          ArkPassOutcome(
            snapshot: observed(
              stale: true,
              renewal: ArkRenewalStatus.delegated,
            ),
            completedStages: {ArkStage.vtxos},
            submittedRounds: ['round'],
          ),
        );
      final reminders = Reminders();
      await RunArkBackgroundUsecase(
        SynchronizeArkUsecase(ArkRepositoryImpl(client)),
        UpdateArkExpiryWarningUsecase(reminders),
      ).execute(account());
      expect(reminders.calls.single.empty, false);
      expect(reminders.calls.single.warning, isNull);
      expect(reminders.calls.single.evidence?.account, account());
      expect(reminders.calls.single.evidence?.revision, 5);
      expect(client.calls, ['renew']);
    },
  );
}
