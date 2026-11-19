import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_vtxos_screen_test.dart' show coin, view;

Future<void> showInventory(
  WidgetTester tester,
  ArkSnapshot snapshot,
  ValueChanged<List<String>> onRenew, {
  VoidCallback? onBoard,
}) async {
  await tester.pumpWidget(
    app(ArkVtxosScreen(snapshot: snapshot, onRenew: onRenew, onBoard: onBoard)),
  );
  await tester.pumpAndSettle();
}

Future<void> openCoin(WidgetTester tester, String id) async {
  final row = find.byKey(ValueKey('vtxo-details-$id'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

BullButton renewButton(WidgetTester tester) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, 'Renew'));

void main() {
  testWidgets('proven empty keeps all five zero-count filters', (tester) async {
    await showInventory(tester, view(values: []), (_) {});
    for (final label in [
      'All 0',
      'Active 0',
      'Expiring 0',
      'Expired 0',
      'Locked 0',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('No VTXOs yet'), findsOneWidget);
    expect(find.text('Bitcoin you receive shows up here.'), findsOneWidget);
    expect(find.widgetWithText(BullButton, 'Renew'), findsNothing);
  });

  testWidgets('buckets follow 0 1 144 145 and locked precedence', (
    tester,
  ) async {
    await showInventory(
      tester,
      view(
        values: [
          coin('zero', expiry: 100),
          coin('one', expiry: 101),
          coin('boundary', expiry: 244),
          coin('active', expiry: 245),
          coin('locked', expiry: 80, state: ArkVtxoState.locked),
          coin('retired', state: ArkVtxoState.spent),
          coin('unknown', state: ArkVtxoState.unknown),
          coin('pending', pendingRound: true),
        ],
      ),
      (_) {},
    );
    for (final label in [
      'All 7',
      'Active 1',
      'Expiring 2',
      'Expired 1',
      'Locked 1',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Expires in 145 blocks'), findsOneWidget);
    expect(find.text('Expiring · in 1 blocks'), findsOneWidget);
    expect(find.text('Expiring · in 144 blocks'), findsOneWidget);
  });

  testWidgets('row opens details and renew dispatches one immutable ID', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await showInventory(tester, view(), calls.add);
    await openCoin(tester, 'shared');
    expect(find.text('VTXO details'), findsOneWidget);
    renewButton(tester).onPressed();
    expect(calls, [
      ['shared'],
    ]);
    expect(() => calls.single.add('other'), throwsUnsupportedError);
  });

  testWidgets(
    'renew saved before detail dismissal remains retired after reopen',
    (tester) async {
      final calls = <List<String>>[];
      await showInventory(tester, view(), calls.add);
      await openCoin(tester, 'shared');
      final saved = renewButton(tester).onPressed;
      tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack?.call();
      await tester.pumpAndSettle();
      saved();
      await openCoin(tester, 'shared');
      saved();
      expect(calls, isEmpty);
      renewButton(tester).onPressed();
      expect(calls, [
        ['shared'],
      ]);
    },
  );

  for (final replacement in <String, ArkSnapshot>{
    'stale': view(stale: true),
    'missing tip': view(tip: null),
    'incomplete': view(completeness: ArkSectionCompleteness.incomplete),
    'delegated': view(renewal: ArkRenewalStatus.delegated),
    'recovery': view(recovery: ArkRecoveryStatus.unknown),
    'duplicate': view(values: [coin('shared'), coin('shared')]),
    'retired': view(values: [coin('shared', state: ArkVtxoState.spent)]),
  }.entries) {
    testWidgets('saved renew refuses ${replacement.key} publication', (
      tester,
    ) async {
      final calls = <List<String>>[];
      final callback = calls.add;
      await showInventory(tester, view(), callback);
      await openCoin(tester, 'shared');
      final saved = renewButton(tester).onPressed;
      await showInventory(tester, replacement.value, callback);
      saved();
      expect(calls, isEmpty);
    });
  }

  testWidgets('saved renew refuses replacement capability and disposal', (
    tester,
  ) async {
    final first = <List<String>>[], second = <List<String>>[];
    final snapshot = view();
    await showInventory(tester, snapshot, first.add);
    await openCoin(tester, 'shared');
    final saved = renewButton(tester).onPressed;
    await showInventory(tester, snapshot, second.add);
    saved();
    expect(first, isEmpty);
    expect(second, isEmpty);
    final current = renewButton(tester).onPressed;
    await tester.pumpWidget(const SizedBox.shrink());
    current();
    expect(second, isEmpty);
  });

  testWidgets(
    'delegated renewal preserves known inventory while disabling actions',
    (tester) async {
      final calls = <List<String>>[];
      await showInventory(
        tester,
        view(renewal: ArkRenewalStatus.delegated),
        calls.add,
      );
      expect(find.text('1,234 sats'), findsNWidgets(2));
      expect(find.text('1 VTXOs'), findsOneWidget);
      await openCoin(tester, 'shared');
      expect(find.text('1,234 sats'), findsOneWidget);
      expect(find.widgetWithText(BullButton, 'Renew'), findsNothing);
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'only raw proven empty can Board, never filtered or retired-only',
    (tester) async {
      var boards = 0;
      await showInventory(
        tester,
        view(values: []),
        (_) {},
        onBoard: () => boards++,
      );
      final saved = tester
          .widget<BullButton>(find.widgetWithText(BullButton, 'Board to Ark'))
          .onPressed;
      for (final snapshot in [
        view(values: [coin('retired', state: ArkVtxoState.spent)]),
        view(values: [], stale: true),
        view(values: [], tip: null),
        view(values: [], completeness: ArkSectionCompleteness.incomplete),
      ]) {
        await showInventory(tester, snapshot, (_) {}, onBoard: () => boards++);
        saved();
        expect(find.widgetWithText(BullButton, 'Board to Ark'), findsNothing);
      }
      expect(boards, 0);
    },
  );
  for (final remaining in [1007, 1008, 1009]) {
    testWidgets(
      'auto-renew note uses the actual threshold at $remaining blocks',
      (tester) async {
        final calls = <List<String>>[];
        await tester.pumpWidget(
          app(
            ArkVtxosScreen(
              snapshot: view(
                values: [coin('threshold', expiry: 100 + remaining)],
              ),
              renewalThresholdBlocks: 1008,
              onRenew: calls.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await openCoin(tester, 'threshold');
        expect(
          find.textContaining('Auto-renew is configured 1008 blocks'),
          remaining < 1008 ? findsOneWidget : findsNothing,
        );
        expect(find.widgetWithText(BullButton, 'Renew'), findsOneWidget);
        await tester.tap(find.widgetWithText(BullButton, 'Renew'));
        expect(calls, [
          ['threshold'],
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
