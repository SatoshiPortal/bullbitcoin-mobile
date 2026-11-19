import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBorderedTile,
        BullButton,
        BullTopBar,
        ValueKey,
        VoidCallback,
        SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app, details;
import 'ark_operations_test.dart' show account;

ArkVtxo coin(
  String id, {
  ArkVtxoState state = ArkVtxoState.spendable,
  bool pendingRound = false,
  int expiry = 500,
  String? anchor,
}) => ArkVtxo(
  id: id,
  amount: Sats.fromInt(1234),
  expiryHeight: expiry,
  state: state,
  pendingRound: pendingRound,
  anchor: anchor,
);
ArkSnapshot view({
  ArkAccountId? owner,
  bool stale = false,
  int? tip = 100,
  ArkSectionCompleteness completeness = ArkSectionCompleteness.complete,
  ArkRecoveryStatus recovery = ArkRecoveryStatus.complete,
  ArkRenewalStatus renewal = ArkRenewalStatus.current,
  List<ArkVtxo>? values,
}) => ArkSnapshot(
  account: owner ?? account(),
  revision: 2,
  observedAt: DateTime.utc(2026, 11, 16),
  tipHeight: tip,
  stale: stale,
  vtxoCompleteness: completeness,
  recovery: recovery,
  renewal: renewal,
  vtxos: values ?? [coin('shared')],
);
Finder tile(String id) => find.byKey(ValueKey('vtxo-details-$id'));
BullButton renew(WidgetTester tester) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, 'Renew'));
Future<void> paint(
  WidgetTester tester,
  ArkSnapshot snapshot,
  List<List<String>> calls, {
  VoidCallback? onBoard,
}) async {
  await tester.pumpWidget(
    app(
      ArkVtxosScreen(snapshot: snapshot, onRenew: calls.add, onBoard: onBoard),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> select(WidgetTester tester, String id) async {
  await tester.ensureVisible(tile(id));
  await tester.tap(tile(id));
  await tester.pumpAndSettle();
}

void main() {
  final other = ArkAccountId(
    parent: account().parent,
    network: BitcoinNetwork.regtest,
    serverIdentity: 'other-server',
  );
  testWidgets('confirmed empty inventory offers Board instead of renewal', (
    tester,
  ) async {
    var boards = 0;
    final calls = <List<String>>[];
    await paint(tester, view(values: []), calls, onBoard: () => boards++);
    expect(find.widgetWithText(BullButton, 'Renew'), findsNothing);
    await tester.tap(find.widgetWithText(BullButton, 'Board to Ark'));
    expect(boards, 1);
    expect(calls, isEmpty);
    await paint(tester, view(values: []), calls);
    expect(find.widgetWithText(BullButton, 'Board to Ark'), findsNothing);
  });
  for (final change in [
    'account',
    'stale',
    'populated',
    'capability',
    'disposed',
  ]) {
    testWidgets('old empty Board refuses $change context', (tester) async {
      var boards = 0;
      int capability() => boards++;
      await paint(tester, view(values: []), [], onBoard: capability);
      final old = tester
          .widget<BullButton>(find.widgetWithText(BullButton, 'Board to Ark'))
          .onPressed;
      if (change == 'disposed') {
        await tester.pumpWidget(const SizedBox.shrink());
      } else {
        await paint(
          tester,
          switch (change) {
            'account' => view(values: [], owner: other),
            'stale' => view(values: [], stale: true),
            'populated' => view(),
            _ => view(values: []),
          },
          [],
          onBoard: change == 'capability' ? () => boards++ : capability,
        );
      }
      old();
      expect(boards, 0);
    });
  }
  testWidgets('replacement Board capability remains usable', (tester) async {
    var first = 0, second = 0;
    await paint(tester, view(values: []), [], onBoard: () => first++);
    final old = tester
        .widget<BullButton>(find.widgetWithText(BullButton, 'Board to Ark'))
        .onPressed;
    await paint(tester, view(values: []), [], onBoard: () => second++);
    old();
    expect(first, 0);
    expect(second, 0);
    await tester.tap(find.widgetWithText(BullButton, 'Board to Ark'));
    expect(second, 1);
  });
  testWidgets('unproven and retired inventories do not offer Board', (
    tester,
  ) async {
    for (final snapshot in [
      view(values: [], stale: true),
      view(values: [], completeness: ArkSectionCompleteness.incomplete),
      view(values: [], tip: null),
      view(values: [], recovery: ArkRecoveryStatus.unknown),
      view(values: [], renewal: ArkRenewalStatus.delegated),
      view(values: [coin('retired', state: ArkVtxoState.spent)]),
    ]) {
      await paint(
        tester,
        snapshot,
        [],
        onBoard: () => fail('Unexpected Board'),
      );
      expect(find.widgetWithText(BullButton, 'Board to Ark'), findsNothing);
    }
    await paint(tester, view(), []);
    await tester.tap(find.text('Locked 0'));
    await tester.pumpAndSettle();
    expect(find.text('No VTXOs match this filter.'), findsOneWidget);
    expect(find.widgetWithText(BullButton, 'Board to Ark'), findsNothing);
  });
  testWidgets(
    'details use observed anchor and missing creation stays unavailable',
    (tester) async {
      final calls = <List<String>>[];
      final values = [coin('shared', anchor: 'actual-anchor')];
      await paint(tester, view(values: values), calls);
      await select(tester, 'shared');
      expect(find.text('VTXO details'), findsOneWidget);
      expect(details(tester), containsPair('Created', 'Unavailable'));
      expect(details(tester), containsPair('Anchor point', 'actual-anchor'));
      expect(details(tester), containsPair('Blocks left', '400'));
      expect(calls, isEmpty);
      await paint(tester, view(values: values, stale: true), calls);
      expect(details(tester), containsPair('Blocks left', 'Unavailable'));
      expect(details(tester), containsPair('Anchor point', 'actual-anchor'));
      expect(find.widgetWithText(BullButton, 'Renew'), findsNothing);
    },
  );
  for (final values in <List<ArkVtxo>>[
    [],
    [coin('shared'), coin('shared')],
  ]) {
    testWidgets(
      'details close when ID disappears or becomes ambiguous ${values.length}',
      (tester) async {
        await paint(tester, view(), []);
        await select(tester, 'shared');
        await paint(tester, view(values: values), []);
        expect(find.text('VTXO details'), findsNothing);
      },
    );
  }
  testWidgets(
    'old row cannot open another account and account change closes detail',
    (tester) async {
      await paint(tester, view(), []);
      final old = tester.widget<BullBorderedTile>(tile('shared')).onTap;
      await paint(tester, view(owner: other), []);
      old?.call();
      await tester.pump();
      expect(find.text('VTXO details'), findsNothing);
      await select(tester, 'shared');
      await paint(tester, view(), []);
      expect(find.text('VTXO details'), findsNothing);
    },
  );
  testWidgets(
    'only eligible details expose renewal and retired rows stay absent',
    (tester) async {
      final values = [
        for (final state in ArkVtxoState.values) coin(state.name, state: state),
        coin('expired', expiry: 100),
        coin('pending-round', pendingRound: true),
      ];
      final calls = <List<String>>[];
      for (final id in [
        'locked',
        'unknown',
        'expired',
        'pending-round',
        'spendable',
      ]) {
        await paint(tester, view(values: values), calls);
        for (final retired in ['spent', 'exited', 'abandonedBoard']) {
          expect(tile(retired), findsNothing);
        }
        await select(tester, id);
        expect(find.text('VTXO details'), findsOneWidget);
        expect(
          find.widgetWithText(BullButton, 'Renew'),
          id == 'spendable' ? findsOneWidget : findsNothing,
        );
        tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack?.call();
        await tester.pumpAndSettle();
      }
      expect(calls, isEmpty);
    },
  );
  testWidgets('only proven empty shows the empty panel', (tester) async {
    await paint(tester, view(values: []), []);
    expect(find.text('No VTXOs yet'), findsOneWidget);
    for (final snapshot in [
      view(values: [], stale: true),
      view(values: [], completeness: ArkSectionCompleteness.incomplete),
    ]) {
      await paint(tester, snapshot, []);
      expect(find.text('No VTXOs yet'), findsNothing);
      expect(find.text('Unavailable'), findsWidgets);
    }
  });
}
