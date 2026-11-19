import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_exit_request_screen.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDetailsTable,
        BullInfoBar,
        BullInputText,
        BullSegmented,
        BullText,
        BullTopBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Size, SizedBox;

import 'ark_exit_request_screen_test.dart' as form;
import 'ark_exit_review_cycle_test.dart' as cycle;
import 'ark_information_widget_test.dart' show app;

BullButton action(WidgetTester tester) => tester.widget<BullButton>(
  find.ancestor(
    of: find.textContaining(RegExp(r'^Review(?: exit)?$')),
    matching: find.byType(BullButton),
  ),
);
Finder label(String text) => find.widgetWithText(BullText, text);

void main() {
  testWidgets('Choose puts observed selection before the full warnings', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(ArkExitRequestScreen(snapshot: form.inventory(), onReview: (_) {})),
    );
    expect(
      tester.getTopLeft(find.byType(BullDetailsTable)).dy,
      lessThan(tester.getTopLeft(find.byType(BullInfoBar).first).dy),
    );
    final warnings = tester
        .widgetList<BullInfoBar>(find.byType(BullInfoBar))
        .map((bar) => bar.message);
    expect(
      warnings.where(
        (message) =>
            message.contains('account-wide') &&
            message.contains('not a strict financial cap'),
      ),
      hasLength(1),
    );
    expect(
      warnings.where(
        (message) => message.contains('Background maintenance never starts'),
      ),
      hasLength(1),
    );
    expect(find.text('selected'), findsNothing);
    expect(find.widgetWithText(BullButton, 'Review exit'), findsOneWidget);
  });
  testWidgets('filled and invalid exit fees keep persistent labels and units', (
    tester,
  ) async {
    final requests = <ArkQuoteRequest>[];
    await tester.pumpWidget(
      app(
        ArkExitRequestScreen(
          snapshot: form.inventory(),
          onReview: requests.add,
        ),
      ),
    );
    await form.fill(tester);
    for (final text in [
      'On-chain return address',
      'Fee rate (sat/vB)',
      'Maximum claim fee (sats)',
    ]) {
      expect(label(text), findsOneWidget);
    }
    await form.edit(tester, 'Fee rate (sat/vB)', '0');
    expect(label('Fee rate (sat/vB)'), findsOneWidget);
    expect(label('Maximum claim fee (sats)'), findsOneWidget);
    expect(action(tester).disabled, isTrue);
    action(tester).onPressed();
    expect(requests, isEmpty);
  });
  testWidgets(
    'fee fields begin empty and stay required without a local estimate',
    (tester) async {
      final requests = <ArkQuoteRequest>[];
      await tester.pumpWidget(
        app(
          ArkExitRequestScreen(
            snapshot: form.inventory(),
            onReview: requests.add,
          ),
        ),
      );
      expect(
        tester
            .widgetList<BullInputText>(find.byType(BullInputText))
            .map((input) => input.value),
        ['', '', ''],
      );
      await form.edit(tester, 'On-chain return address', 'bcrt1-return');
      expect(action(tester).disabled, isTrue);
      await form.edit(tester, 'Fee rate (sat/vB)', '2');
      expect(action(tester).disabled, isTrue);
      expect(requests, isEmpty);
      await form.edit(tester, 'Maximum claim fee (sats)', '500');
      expect(action(tester).disabled, isFalse);
      final old = action(tester).onPressed;
      old();
      old();
      expect(requests, hasLength(1));
      final value = requests.single as ArkEmergencyExitQuoteRequest;
      expect(value.ids, ['selected']);
      expect(value.feeRate.satsPerVbyte, 2);
      expect(value.maxClaimFee.value.toInt(), 500);
    },
  );
  testWidgets(
    'real module entry and edits do not quote before explicit Review',
    (tester) async {
      final rig = cycle.rigFor('start');
      await cycle.openForm(tester, rig, 'start');
      expect(
        rig.client.calls.where((v) => v == 'quote' || v == 'submit'),
        isEmpty,
      );
      cycle.review(tester, 'start').onPressed();
      await tester.pumpAndSettle();
      expect(rig.client.calls.where((v) => v == 'quote'), hasLength(1));
      expect(rig.client.calls.where((v) => v == 'submit'), isEmpty);
      expect(
        find.descendant(
          of: find.descendant(
            of: find.byType(ArkOperationReviewScreen),
            matching: find.byType(BullTopBar),
          ),
          matching: find.text('Review exit'),
        ),
        findsOneWidget,
      );
    },
  );
  for (final snapshot in [
    form.inventory(stale: true),
    form.inventory(complete: false),
  ]) {
    testWidgets(
      'unknown observation cannot enter Review stale=${snapshot.stale}',
      (tester) async {
        final requests = <ArkQuoteRequest>[];
        await tester.pumpWidget(
          app(ArkExitRequestScreen(snapshot: snapshot, onReview: requests.add)),
        );
        await form.fill(tester);
        action(tester).onPressed();
        expect(action(tester).disabled, isTrue);
        expect(requests, isEmpty);
      },
    );
  }
  testWidgets('Claim keeps its existing form and review contract', (
    tester,
  ) async {
    final requests = <ArkQuoteRequest>[];
    await tester.pumpWidget(
      app(
        ArkExitRequestScreen(
          snapshot: form.inventory(),
          claimIds: const ['claimable'],
          onReview: requests.add,
        ),
      ),
    );
    await form.fill(tester, claim: true);
    expect(find.widgetWithText(BullButton, 'Review'), findsOneWidget);
    expect(find.byType(BullInputText), findsNWidgets(2));
    action(tester).onPressed();
    expect((requests.single as ArkClaimQuoteRequest).ids, ['claimable']);
  });
  testWidgets(
    'small viewport retains the fixed CTA and retires an old draft action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <ArkQuoteRequest>[];
      await tester.pumpWidget(
        app(
          ArkExitRequestScreen(
            snapshot: form.inventory(),
            onReview: requests.add,
          ),
        ),
      );
      await form.fill(tester);
      final old = action(tester).onPressed;
      expect(
        tester.getBottomRight(find.byType(BullButton)).dy,
        lessThanOrEqualTo(640),
      );
      tester
          .widget<BullSegmented>(find.byType(BullSegmented))
          .onSelected('Selected VTXOs');
      await tester.pump();
      old();
      expect(requests, isEmpty);
      await tester.pumpWidget(app(const SizedBox.shrink()));
      old();
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
