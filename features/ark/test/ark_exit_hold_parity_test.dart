import 'dart:ui' show SemanticsAction;

import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_exit_hold_button.dart';
import 'package:material_ui/material_ui.dart'
    show StatefulBuilder, StateSetter, SizedBox;
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operation_review_screen_test.dart' show Rig;

Rig exitRig() {
  final request = ArkQuoteRequest.emergencyExit(
    ids: ['selected-vtxo'],
    destination: 'reviewed-destination',
    feeRate: FeeRate(2),
    maxClaimFee: Sats.fromInt(500),
  ) as ArkEmergencyExitQuoteRequest;
  final rig = Rig(request: request);
  final quote = ArkQuote(
    id: 'explicit-exit-review',
    account: rig.cubit.account,
    generation: 2,
    chainSource: Uri.parse('http://localhost:3000'),
    configGeneration: 1,
    kind: ArkOperationKind.emergencyExit,
    amount: Sats.fromInt(60000),
    fee: Sats.fromInt(1000),
    net: Sats.fromInt(59000),
    selectedIds: request.ids,
    destination: request.destination,
    feeRate: request.feeRate,
    maxClaimFee: request.maxClaimFee,
    confirmedReserveExposure: Sats.fromInt(1500),
    observedTip: 600,
    validUntil: DateTime.utc(2030),
  );
  rig.cubit.emit(ArkOperationReview(quote));
  return rig;
}

void main() {
  testWidgets(
    'exit hold consumes the exact reviewed intent once after 1520ms',
    (tester) async {
      final rig = exitRig();
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      final hold = find.text('Hold to start exit');
      expect(hold, findsOneWidget);
      expect(find.widgetWithText(BullButton, 'Confirm'), findsNothing);
      await tester.tap(hold);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(rig.client.calls, isEmpty);
      final early = await tester.startGesture(tester.getCenter(hold));
      await tester.pump(const Duration(milliseconds: 1480));
      await early.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(rig.client.calls, isEmpty);
      final complete = await tester.startGesture(tester.getCenter(hold));
      await tester.pump(const Duration(milliseconds: 1520));
      await complete.up();
      await tester.pumpAndSettle();
      expect(rig.client.calls, ['submit']);
      expect(rig.ids, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('the same review can finish a hold across a parent rebuild', (
    tester,
  ) async {
    final rig = exitRig();
    await tester.pumpWidget(app(rig.screen));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold to start exit')),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpWidget(app(rig.screen));
    await tester.pump(const Duration(milliseconds: 720));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(rig.client.calls, ['submit']);
    final submission =
        (rig.client.arguments.single as (ArkAccountId, ArkSubmission)).$2;
    expect((submission as ArkConfirmQuote).quoteId, 'explicit-exit-review');
    expect(rig.ids, 1);
  });

  testWidgets(
    'accessible confirmation survives a same-review rebuild and closes before dispatch',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final rig = exitRig();
        await tester.pumpWidget(app(rig.screen));
        await tester.pumpAndSettle();
        tester.semantics.performAction(
          find.semantics.byLabel('Hold to start exit'),
          SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(find.text('Confirm emergency exit'), findsOneWidget);
        expect(rig.client.calls, isEmpty);
        await tester.pumpWidget(app(rig.screen));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(BullButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(rig.client.calls, ['submit']);
        expect(rig.ids, 1);
        expect(find.text('Confirm emergency exit'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'accessible confirmation ignores a hold removed under its dialog',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var visible = true;
        var submitted = 0;
        late StateSetter redraw;
        await tester.pumpWidget(
          app(
            StatefulBuilder(
              builder: (context, setState) {
                redraw = setState;
                return visible
                    ? ArkExitHoldButton(
                        enabled: true,
                        reviewIdentity: 'original-review',
                        current: () => true,
                        onConfirm: () => submitted++,
                      )
                    : const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester.semantics.performAction(
          find.semantics.byLabel('Hold to start exit'),
          SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(find.text('Confirm emergency exit'), findsOneWidget);
        redraw(() => visible = false);
        await tester.pumpAndSettle();
        expect(find.byType(ArkExitHoldButton), findsNothing);
        await tester.tap(find.widgetWithText(BullButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(submitted, 0);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
