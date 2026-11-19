import 'dart:ui' show SemanticsAction;

import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operation_review_screen_test.dart' show Rig, reviewed;
import 'ark_exit_hold_parity_test.dart' show exitRig;

ArkQuote deadline(ArkQuote quote, DateTime until) => ArkQuote(
  id: quote.id,
  account: quote.account,
  generation: quote.generation,
  chainSource: quote.chainSource,
  configGeneration: quote.configGeneration,
  kind: quote.kind,
  amount: quote.amount,
  fee: quote.fee,
  net: quote.net,
  selectedIds: quote.selectedIds,
  destination: quote.destination,
  feeRate: quote.feeRate,
  maxClaimFee: quote.maxClaimFee,
  confirmedReserveExposure: quote.confirmedReserveExposure,
  observedTip: quote.observedTip,
  validUntil: until,
);

BullButton button(WidgetTester tester, String label) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, label));

void main() {
  testWidgets(
    'expired review requires a fresh explicit Review and retires old actions',
    (tester) async {
      final rig = Rig();
      rig.cubit.emit(
        ArkOperationReview(
          deadline(reviewed(rig.cubit.account), DateTime.utc(2020)),
        ),
      );
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      expect(button(tester, 'Confirm').disabled, true);
      expect(find.textContaining('expired'), findsWidgets);
      final oldConfirm = button(tester, 'Confirm').onPressed;
      final oldReview = button(tester, 'Review').onPressed;
      oldConfirm();
      expect(rig.client.calls, isEmpty);
      rig.client.quoted = Ok(reviewed(rig.cubit.account));
      await tester.ensureVisible(find.widgetWithText(BullButton, 'Review'));
      await tester.tap(find.widgetWithText(BullButton, 'Review'));
      await tester.pumpAndSettle();
      expect(rig.client.calls, ['quote']);
      expect(button(tester, 'Confirm').disabled, false);
      oldConfirm();
      oldReview();
      await tester.pumpAndSettle();
      expect(rig.client.calls, ['quote']);
      expect(rig.cubit.confirmationAttempted, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'elapsed review timer survives same-review rebuild without an automatic quote',
    (tester) async {
      final rig = Rig();
      rig.cubit.emit(
        ArkOperationReview(
          deadline(
            reviewed(rig.cubit.account),
            DateTime.now().toUtc().add(const Duration(seconds: 3)),
          ),
        ),
      );
      await tester.pumpWidget(app(rig.screen));
      await tester.pump();
      final oldConfirm = button(tester, 'Confirm').onPressed;
      expect(button(tester, 'Confirm').disabled, false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(app(rig.screen));
      await tester.pump(const Duration(seconds: 2));
      expect(button(tester, 'Confirm').disabled, true);
      expect(find.textContaining('expired'), findsWidgets);
      oldConfirm();
      expect(rig.client.calls, isEmpty);
      expect(rig.ids, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an accessible dialog cannot consume a review whose timer elapsed',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final rig = exitRig();
        final original = rig.cubit.state as ArkOperationReview;
        rig.cubit.emit(
          ArkOperationReview(
            deadline(
              original.quote,
              DateTime.now().toUtc().add(const Duration(seconds: 3)),
            ),
          ),
        );
        await tester.pumpWidget(app(rig.screen));
        await tester.pumpAndSettle();
        tester.semantics.performAction(
          find.semantics.byLabel('Hold to start exit'),
          SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(find.text('Confirm emergency exit'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.tap(find.widgetWithText(BullButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(rig.client.calls, isEmpty);
        expect(rig.ids, 0);
        expect(find.textContaining('expired'), findsWidgets);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
