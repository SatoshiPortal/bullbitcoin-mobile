import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_account_screen.dart';
import 'package:bull_ark/src/ui/ark_exits_screen.dart';
import 'package:bull_ark/src/ui/ark_exit_request_screen.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullBorderedTile, BullButton, BullTopBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show SingleChildScrollView, Offset, Size;

import 'ark_information_widget_test.dart' show app;
import 'ark_exits_screen_test.dart' show Harness, view, exitRow;
import 'ark_module_composition_test.dart' show accountPage, frame;
import 'ark_exit_review_cycle_test.dart' as cycle;
import 'ark_exit_request_screen_test.dart' as inputs;

BullButton action(WidgetTester tester, String label) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, label));
Future<void> detail(WidgetTester tester, [int index = 0]) async {
  await tester.tap(find.byType(BullBorderedTile).at(index));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'retired LIST Start Progress Refresh and row callbacks cannot revive after local navigation',
    (tester) async {
      var starts = 0, progress = 0, refresh = 0, claims = 0;
      final snapshot = view(
        rows: [
          exitRow(),
          exitRow(id: 'other'),
        ],
      );
      await tester.pumpWidget(
        app(
          ArkExitsScreen(
            snapshot: snapshot,
            onReviewExit: () => starts++,
            onReviewProgress: () => progress++,
            onReviewClaim: (_) => claims++,
            onRefresh: () => refresh++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final old = [
        action(tester, 'Start emergency exit').onPressed,
        action(tester, 'Progress emergency exits').onPressed,
        action(tester, 'Refresh').onPressed,
        tester
            .widget<BullButton>(find.widgetWithText(BullButton, 'Claim').first)
            .onPressed,
      ];
      final row = tester
          .widget<BullBorderedTile>(find.byType(BullBorderedTile).last)
          .onTap;
      await detail(tester);
      for (final callback in old) {
        callback();
      }
      row?.call();
      await tester.pumpAndSettle();
      expect(find.text('shared'), findsOneWidget);
      expect([starts, progress, refresh, claims], [0, 0, 0, 0]);
      final oldDone = action(tester, 'Done').onPressed;
      oldDone();
      await tester.pumpAndSettle();
      for (final callback in old) {
        callback();
      }
      row?.call();
      oldDone();
      await tester.pumpAndSettle();
      expect(find.byType(BullBorderedTile), findsNWidgets(2));
      expect([starts, progress, refresh, claims], [0, 0, 0, 0]);
      action(tester, 'Refresh').onPressed();
      action(tester, 'Start emergency exit').onPressed();
      action(tester, 'Progress emergency exits').onPressed();
      tester
          .widget<BullButton>(find.widgetWithText(BullButton, 'Claim').first)
          .onPressed();
      expect([starts, progress, refresh, claims], [1, 1, 1, 1]);
    },
  );
  testWidgets(
    'deep LIST taps start each detail at its top across return and another ID',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Finder scrollView() => find
          .ancestor(
            of: find.byType(BullTopBar),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      final rig = Harness(
        view(rows: List.generate(45, (i) => exitRow(id: 'deep-$i'))),
      );
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      await tester.drag(scrollView(), const Offset(0, -2200));
      await tester.pumpAndSettle();
      final first = find.byType(BullBorderedTile).at(30);
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(BullTopBar)).dy, lessThan(0));
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.text('deep-30'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Exit details')).dy,
        inInclusiveRange(0, 100),
      );
      expect(
        tester.getTopLeft(find.text('1,234 sats')).dy,
        inInclusiveRange(0, 200),
      );
      await tester.drag(scrollView(), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(BullButton, 'Done'));
      await tester.pumpAndSettle();
      final second = find.byType(BullBorderedTile).at(31);
      await tester.ensureVisible(second);
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(find.text('deep-31'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Exit details')).dy,
        inInclusiveRange(0, 100),
      );
      expect(
        tester.getTopLeft(find.text('1,234 sats')).dy,
        inInclusiveRange(0, 200),
      );
      expect(rig.untouched, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'same-account publication preserves readonly detail and retires old actions',
    (tester) async {
      final first = Harness(view());
      await tester.pumpWidget(app(first.screen));
      await detail(tester);
      final oldClaim = action(tester, 'Claim').onPressed;
      final oldDone = action(tester, 'Done').onPressed;
      final second = Harness(view(stale: true));
      await tester.pumpWidget(app(second.screen));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(BullButton, 'Done'), findsOneWidget);
      oldClaim();
      oldDone();
      await tester.pumpAndSettle();
      expect(first.untouched, isTrue);
      expect(second.untouched, isTrue);
      expect(action(tester, 'Claim').disabled, isTrue);
      action(tester, 'Claim').onPressed();
      expect(second.untouched, isTrue);
      action(tester, 'Done').onPressed();
      await tester.pumpAndSettle();
      expect(find.byType(BullBorderedTile), findsOneWidget);
    },
  );
  testWidgets(
    'new fresh publication keeps the selected ID and only its new claim acts',
    (tester) async {
      final first = Harness(view());
      await tester.pumpWidget(app(first.screen));
      await detail(tester);
      final oldClaim = action(tester, 'Claim').onPressed;
      final second = Harness(view());
      await tester.pumpWidget(app(second.screen));
      await tester.pumpAndSettle();
      oldClaim();
      expect(first.untouched, isTrue);
      expect(second.untouched, isTrue);
      expect(find.text('shared'), findsOneWidget);
      action(tester, 'Claim').onPressed();
      expect(second.claims, [
        ['shared'],
      ]);
    },
  );
  testWidgets('account replacement clears detail and retires its navigation', (
    tester,
  ) async {
    final first = Harness(view());
    await tester.pumpWidget(app(first.screen));
    await detail(tester);
    final oldClaim = action(tester, 'Claim').onPressed;
    final oldDone = action(tester, 'Done').onPressed;
    final previous = first.snapshot.account;
    final second = Harness(
      view(
        owner: ArkAccountId(
          parent: previous.parent,
          network: previous.network,
          serverIdentity: 'replacement-server',
        ),
      ),
    );
    await tester.pumpWidget(app(second.screen));
    await tester.pumpAndSettle();
    oldClaim();
    oldDone();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(BullButton, 'Done'), findsNothing);
    expect(find.byType(BullBorderedTile), findsOneWidget);
    expect(first.untouched, isTrue);
    expect(second.untouched, isTrue);
  });
  for (final (label, rows) in <(String, List<ArkExit>)>[
    ('missing', []),
    ('duplicate', [exitRow(), exitRow()]),
    ('empty', [exitRow(id: '')]),
  ]) {
    testWidgets(
      '$label selected identity returns to list and cannot revive a claim',
      (tester) async {
        final first = Harness(view());
        await tester.pumpWidget(app(first.screen));
        await detail(tester);
        final old = action(tester, 'Claim').onPressed;
        final next = Harness(view(rows: rows));
        await tester.pumpWidget(app(next.screen));
        await tester.pumpAndSettle();
        old();
        expect(next.untouched, isTrue);
        expect(find.widgetWithText(BullButton, 'Done'), findsNothing);
        if (rows.isNotEmpty) {
          tester
              .widget<BullBorderedTile>(find.byType(BullBorderedTile).first)
              .onTap
              ?.call();
          await tester.pumpAndSettle();
          expect(find.widgetWithText(BullButton, 'Done'), findsNothing);
        }
      },
    );
  }
  testWidgets(
    'real route detail Back Done and Claim review preserve owner and never submit automatically',
    (tester) async {
      final rig = cycle.rigFor('claim');
      await accountPage(tester, rig);
      tester.widget<ArkAccountScreen>(find.byType(ArkAccountScreen)).onExits();
      await frame(tester);
      final owner = tester.state(find.byType(ArkExitsScreen));
      final before = List<String>.of(rig.client.calls);
      await detail(tester);
      await tester.binding.handlePopRoute();
      await frame(tester);
      expect(tester.state(find.byType(ArkExitsScreen)), same(owner));
      expect(find.byType(BullBorderedTile), findsOneWidget);
      expect(rig.client.calls, before);
      await detail(tester);
      action(tester, 'Done').onPressed();
      await frame(tester);
      expect(tester.state(find.byType(ArkExitsScreen)), same(owner));
      expect(rig.client.calls, before);
      await detail(tester);
      final oldClaim = action(tester, 'Claim').onPressed;
      oldClaim();
      await frame(tester);
      expect(find.byType(ArkExitRequestScreen), findsOneWidget);
      final expectedAfterOpen = [...before, 'read'];
      expect(rig.client.calls, expectedAfterOpen);
      oldClaim();
      await frame(tester);
      expect(rig.client.calls, expectedAfterOpen);
      await inputs.fill(tester, claim: true);
      cycle.review(tester, 'claim').onPressed();
      await frame(tester);
      expect(find.byType(ArkOperationReviewScreen), findsOneWidget);
      expect(rig.client.calls.where((c) => c == 'quote'), hasLength(1));
      expect(rig.client.calls.where((c) => c == 'submit'), isEmpty);
      cycle.cancel(tester);
      await frame(tester);
      tester
          .widget<BullTopBar>(
            find.descendant(
              of: find.byType(ArkExitRequestScreen),
              matching: find.byType(BullTopBar),
            ),
          )
          .onBack
          ?.call();
      await frame(tester);
      expect(tester.state(find.byType(ArkExitsScreen)), same(owner));
      expect(find.widgetWithText(BullButton, 'Done'), findsOneWidget);
      expect(rig.client.calls.where((c) => c == 'quote'), hasLength(1));
      expect(rig.client.calls.where((c) => c == 'submit'), isEmpty);
    },
  );
}
