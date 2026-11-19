import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:material_ui/material_ui.dart' show Size;

import 'ark_information_widget_test.dart' show app;
import 'ark_operation_review_screen_test.dart' show Rig;

Future<Rig> acceptedResult({
  ArkOperationKind kind = ArkOperationKind.renewal,
  ArkOperationStatus status = ArkOperationStatus.succeeded,
}) async {
  final rig = Rig();
  await rig.ready();
  rig.client.submitted = Ok(
    ArkOperation(
      id: 'accepted-operation',
      kind: kind,
      status: status,
      chainSource: Uri.parse('http://localhost:3000'),
      configGeneration: 1,
      skippedIds: ['skipped-input'],
    ),
  );
  await rig.cubit.confirm();
  expect(rig.client.calls, ['quote', 'submit']);
  return rig;
}

void main() {
  testWidgets('accepted renewal Done stays at the viewport footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rig = await acceptedResult();
    await tester.pumpWidget(
      app(
        ArkOperationReviewScreen(
          cubit: rig.cubit,
          onReconcile: () {},
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.widgetWithText(BullButton, 'Done')).dy,
      greaterThan(780),
    );
  });
  testWidgets('accepted renewal separates operation details from the result', (
    tester,
  ) async {
    final rig = await acceptedResult();
    await tester.pumpWidget(
      app(
        ArkOperationReviewScreen(
          cubit: rig.cubit,
          onReconcile: () {},
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(BullButton, 'Operation details'),
      findsOneWidget,
    );
    expect(find.text('accepted-operation'), findsNothing);
    expect(find.text('Completed'), findsNothing);
    expect(find.text('900 sats'), findsNothing);
  });
  testWidgets('mismatched submitted kind never claims renewal started', (
    tester,
  ) async {
    final rig = await acceptedResult(kind: ArkOperationKind.emergencyExit);
    await tester.pumpWidget(
      app(
        ArkOperationReviewScreen(
          cubit: rig.cubit,
          onReconcile: () {},
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Renewal started'), findsNothing);
    expect(find.text('Emergency exit started'), findsNothing);
    expect(rig.client.calls, ['quote', 'submit']);
  });
}
