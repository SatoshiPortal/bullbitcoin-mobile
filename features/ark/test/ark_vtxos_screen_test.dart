import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBorderedTile,
        BullButton,
        BullTopBar,
        ValueKey,
        GestureDetector,
        BullText,
        BullTextRole;
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
Finder tile(String id) =>
    find.ancestor(of: find.text(id), matching: find.byType(BullBorderedTile));
BullButton renew(WidgetTester tester) => tester.widget<BullButton>(
  find.widgetWithText(BullButton, 'Review renewal'),
);
Future<void> paint(
  WidgetTester tester,
  ArkSnapshot snapshot,
  List<List<String>> calls,
) async {
  await tester.pumpWidget(
    app(ArkVtxosScreen(snapshot: snapshot, onRenew: calls.add)),
  );
  await tester.pumpAndSettle();
}

Future<void> select(WidgetTester tester, String id) async {
  await tester.ensureVisible(tile(id));
  await tester.tap(tile(id));
  await tester.pump();
}

void main() {
  final other = ArkAccountId(
    parent: account().parent,
    network: BitcoinNetwork.regtest,
    serverIdentity: 'other-server',
  );
  testWidgets('retired VTXOs do not inflate the total or live count', (
    tester,
  ) async {
    await paint(
      tester,
      view(
        values: [
          coin('live'),
          coin('spent', state: ArkVtxoState.spent),
          coin('exited', state: ArkVtxoState.exited),
          coin('abandoned', state: ArkVtxoState.abandonedBoard),
        ],
      ),
      [],
    );
    expect(find.text('1 VTXOs'), findsOneWidget);
    final total = tester.widget<BullText>(
      find.byWidgetPredicate(
        (widget) => widget is BullText && widget.role == BullTextRole.headline,
      ),
    );
    expect(total.text, '1,234 sats');
    expect(find.text('4 VTXOs'), findsNothing);
    expect(find.text('4,936 sats'), findsNothing);
  });

  testWidgets('account replacement clears same-string selection', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(tester, view(), calls);
    await select(tester, 'shared');
    expect(renew(tester).disabled, false);
    await paint(tester, view(owner: other), calls);
    expect(renew(tester).disabled, true);
    expect(calls, isEmpty);
  });
  testWidgets('old row tap cannot repopulate another account selection', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(tester, view(), calls);
    final oldTap = tester.widget<BullBorderedTile>(tile('shared')).onTap;
    expect(oldTap, isNotNull);
    await paint(tester, view(owner: other), calls);
    oldTap?.call();
    await tester.pump();
    expect(renew(tester).disabled, true);
    expect(calls, isEmpty);
  });
  testWidgets('old renewal callback cannot send selection to a new account', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(tester, view(), calls);
    await select(tester, 'shared');
    final oldRenew = renew(tester).onPressed;
    await paint(tester, view(owner: other), calls);
    oldRenew();
    expect(calls, isEmpty);
  });

  testWidgets('details use observed data and never select a renewal', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(tester, view(), calls);
    await tester.tap(find.byKey(const ValueKey('vtxo-details-shared')));
    await tester.pumpAndSettle();
    expect(find.text('VTXO details'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Anchor'), findsOneWidget);
    expect(find.text('Unavailable'), findsNWidgets(2));
    expect(find.text('400'), findsOneWidget);
    expect(renew(tester).disabled, true);
    expect(calls, isEmpty);
    tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack?.call();
    await tester.pumpAndSettle();
    expect(find.text('Total value'), findsOneWidget);
    expect(renew(tester).disabled, true);
  });
  testWidgets('account replacement closes the previous account details', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(tester, view(), calls);
    await tester.tap(find.byKey(const ValueKey('vtxo-details-shared')));
    await tester.pumpAndSettle();
    final oldDetails = tester.widget<BullTopBar>(find.byType(BullTopBar));
    expect(oldDetails.title, 'VTXO details');
    await paint(tester, view(owner: other), calls);
    expect(find.text('VTXO details'), findsNothing);
    expect(find.text('Total value'), findsOneWidget);
  });
  testWidgets('filters never imply that an inventory is empty', (tester) async {
    final calls = <List<String>>[];
    await paint(tester, view(), calls);
    await tester.tap(find.text('Locked 0'));
    await tester.pumpAndSettle();
    expect(find.text('No VTXOs match this filter.'), findsOneWidget);
    expect(find.text('No items in this observed inventory.'), findsNothing);
    expect(renew(tester).disabled, true);
  });
  testWidgets('details close when their ID disappears or becomes ambiguous', (
    tester,
  ) async {
    final calls = <List<String>>[];
    for (final values in <List<ArkVtxo>>[
      [],
      [coin('shared'), coin('shared')],
    ]) {
      await paint(tester, view(), calls);
      await tester.tap(find.byKey(const ValueKey('vtxo-details-shared')));
      await tester.pumpAndSettle();
      expect(find.text('VTXO details'), findsOneWidget);
      await paint(tester, view(values: values), calls);
      expect(find.text('VTXO details'), findsNothing);
    }
    expect(calls, isEmpty);
  });
  testWidgets('old details callback cannot open a replacement account', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(tester, view(), calls);
    final oldOpen = tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey('vtxo-details-shared')),
        )
        .onTap;
    await paint(tester, view(owner: other), calls);
    oldOpen?.call();
    await tester.pumpAndSettle();
    expect(find.text('VTXO details'), findsNothing);
    expect(calls, isEmpty);
  });
  testWidgets(
    'details retain real anchor and invalidate stale blocks remaining',
    (tester) async {
      final calls = <List<String>>[];
      final values = [coin('shared', anchor: 'actual-anchor')];
      await paint(tester, view(values: values), calls);
      await tester.tap(find.byKey(const ValueKey('vtxo-details-shared')));
      await tester.pumpAndSettle();
      expect(details(tester), containsPair('Anchor', 'actual-anchor'));
      expect(details(tester), containsPair('Blocks remaining', '400'));
      await paint(tester, view(values: values, stale: true), calls);
      expect(details(tester), containsPair('Blocks remaining', 'Unavailable'));
      expect(details(tester), containsPair('Anchor', 'actual-anchor'));
      expect(renew(tester).disabled, true);
      expect(calls, isEmpty);
    },
  );
  final invalid = {
    'stale': view(stale: true),
    'incomplete': view(completeness: ArkSectionCompleteness.incomplete),
    'missing tip': view(tip: null),
    'recovery unknown': view(recovery: ArkRecoveryStatus.unknown),
    'delegated': view(renewal: ArkRenewalStatus.delegated),
  };
  for (final entry in invalid.entries) {
    testWidgets(
      '${entry.key} purges selection instead of hiding it until fresh',
      (tester) async {
        final calls = <List<String>>[];
        await paint(tester, view(), calls);
        await select(tester, 'shared');
        final oldRenew = renew(tester).onPressed;
        await paint(tester, entry.value, calls);
        expect(renew(tester).disabled, true);
        await paint(tester, view(), calls);
        expect(renew(tester).disabled, true);
        oldRenew();
        expect(calls, isEmpty);
      },
    );
  }
  testWidgets(
    'explicit same-account selection emits exact immutable IDs only',
    (tester) async {
      final calls = <List<String>>[];
      await paint(tester, view(), calls);
      expect(calls, isEmpty);
      await select(tester, 'shared');
      expect(calls, isEmpty);
      renew(tester).onPressed();
      expect(calls, [
        ['shared'],
      ]);
      expect(() => calls.single.add('not-selected'), throwsUnsupportedError);
    },
  );
  testWidgets(
    'raw rows show explicit sats while domain-ineligible IDs stay read-only',
    (tester) async {
      final values = [
        for (final state in ArkVtxoState.values) coin(state.name, state: state),
        coin('expired', expiry: 100),
        coin('pending-round', pendingRound: true),
      ];
      final calls = <List<String>>[];
      await paint(tester, view(values: values), calls);
      expect(find.text('1,234 sats'), findsNWidgets(values.length));
      for (final id in [
        'locked',
        'spent',
        'exited',
        'unknown',
        'expired',
        'pending-round',
      ]) {
        expect(tester.widget<BullBorderedTile>(tile(id)).onTap, isNull);
      }
      expect(
        tester.widget<BullBorderedTile>(tile('spendable')).onTap,
        isNotNull,
      );
      expect(calls, isEmpty);
    },
  );
  testWidgets('only current complete observed empty inventory displays empty', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(tester, view(values: []), calls);
    expect(find.text('No items in this observed inventory.'), findsOneWidget);
    for (final snapshot in [
      view(values: [], stale: true),
      view(values: [], completeness: ArkSectionCompleteness.incomplete),
    ]) {
      await paint(tester, snapshot, calls);
      expect(find.text('No items in this observed inventory.'), findsNothing);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(renew(tester).disabled, true);
    }
    expect(calls, isEmpty);
  });
}
