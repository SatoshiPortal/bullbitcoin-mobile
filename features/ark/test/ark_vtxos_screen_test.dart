import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDetailsTable,
        BullDetailsTableItem,
        BullInfoBar,
        BullTopBar,
        Center,
        Column,
        GestureDetector,
        Navigator,
        ValueKey,
        VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show NavigatorState;
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app, details;
import 'ark_operations_test.dart' show account;

const threshold = 1008;

ArkVtxo coin(
  String id, {
  ArkVtxoState state = ArkVtxoState.spendable,
  bool pendingRound = false,
  int expiry = 500,
  int amount = 1234,
  String? anchor,
}) => ArkVtxo(
  id: id,
  amount: Sats.fromInt(amount),
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
  List<ArkMovement> movements = const [],
  List<ArkExit> exits = const [],
  List<ArkOperation> operations = const [],
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
  movements: movements,
  exitDetails: exits,
  operations: operations,
);

Finder row(String id) => find.byKey(ValueKey('vtxo-details-$id'));
Finder renewButton() => find.widgetWithText(BullButton, 'Renew');
BullButton renew(WidgetTester tester) =>
    tester.widget<BullButton>(renewButton());

Future<void> paint(
  WidgetTester tester,
  ArkSnapshot snapshot,
  List<List<String>> calls, {
  VoidCallback? onBoard,
  bool renewStarts = false,
}) async {
  await tester.pumpWidget(
    app(
      ArkVtxosScreen(
        snapshot: snapshot,
        renewalThresholdBlocks: threshold,
        onRenew: (ids) async {
          calls.add(ids);
          return renewStarts;
        },
        onBoard: onBoard,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, String id) async {
  await tester.ensureVisible(row(id));
  await tester.tap(row(id));
  await tester.pumpAndSettle();
}

void main() {
  final other = ArkAccountId(
    parent: account().parent,
    network: BitcoinNetwork.regtest,
    serverIdentity: 'other-server',
  );

  testWidgets('list shows the total, summary and rows without a bulk action', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(
      tester,
      view(
        values: [
          coin('active', expiry: 2000, amount: 2000),
          coin('expiring', amount: 1000),
          coin('expired', expiry: 90, amount: 500),
          coin('locked', state: ArkVtxoState.locked, amount: 300),
        ],
      ),
      calls,
    );
    expect(find.text('Total in Ark'), findsOneWidget);
    // The expired VTXO is not counted as funds in Ark.
    expect(find.text('3,300 sats'), findsOneWidget);
    expect(find.text('3 VTXOs · Next expiry in ~3 days'), findsOneWidget);
    expect(find.text('Expires in ~13 days'), findsOneWidget);
    expect(find.text('Expiring · in ~3 days'), findsOneWidget);
    expect(find.text('Expired'), findsWidgets);
    expect(find.text('Locked'), findsOneWidget);
    expect(renewButton(), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('a Board released unsigned is neither listed nor counted', (
    tester,
  ) async {
    await paint(
      tester,
      view(
        values: [
          coin('active', expiry: 2000, amount: 2000),
          coin('ghost', state: ArkVtxoState.abandonedBoard, amount: 19670),
        ],
      ),
      [],
    );
    expect(find.text('2,000 sats'), findsNWidgets(2)); // Total and its row.
    expect(find.text('19,670 sats'), findsNothing);
    expect(find.text('1 VTXO · Next expiry in ~13 days'), findsOneWidget);
    expect(find.textContaining('Locked 0'), findsOneWidget);
  });

  testWidgets('rows sort by expiry and expose a named details button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await paint(
      tester,
      view(values: [coin('late', expiry: 3000), coin('soon', expiry: 200)]),
      [],
    );
    expect(
      tester.getTopLeft(row('soon')).dy,
      lessThan(tester.getTopLeft(row('late')).dy),
    );
    expect(
      tester.getSemantics(row('soon')),
      matchesSemantics(
        label: '1,234 sats, Expiring · in ~17 hours. Show details',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('an unknown-state VTXO makes the total unknown, not smaller', (
    tester,
  ) async {
    await paint(
      tester,
      view(
        values: [
          coin('shared'),
          coin('mystery', state: ArkVtxoState.unknown),
        ],
      ),
      [],
    );
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('1,234 sats'), findsNWidgets(2));
  });

  testWidgets('filters classify against the renewal threshold', (tester) async {
    await paint(
      tester,
      view(
        values: [
          coin('active', expiry: 2000),
          coin('expiring'),
          coin('expired', expiry: 100),
          coin('locked', state: ArkVtxoState.locked),
          coin('round', pendingRound: true),
          coin('spent', state: ArkVtxoState.spent),
        ],
      ),
      [],
    );
    // The spent VTXO is history and never counted.
    for (final label in [
      'All 5',
      'Active 1',
      'Expiring 1',
      'Expired 1',
      'Locked 2',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // A VTXO in a round is locked like any other until the round ends.
    expect(find.text('Locked'), findsNWidgets(2));
    await tester.tap(find.text('Locked 2'));
    await tester.pumpAndSettle();
    expect(row('locked'), findsOneWidget);
    expect(row('round'), findsOneWidget);
    expect(row('active'), findsNothing);
  });

  testWidgets('stale data never classifies expiry', (tester) async {
    await paint(
      tester,
      view(stale: true, values: [coin('old', expiry: 100)]),
      [],
    );
    expect(find.text('Expired 0'), findsOneWidget);
    expect(find.text('Active 0'), findsOneWidget);
    expect(find.text('Spendable'), findsOneWidget);
    expect(
      find.text('Last observed data. Refresh before reviewing a payment.'),
      findsOneWidget,
    );
  });

  testWidgets('a filter with no match never implies an empty inventory', (
    tester,
  ) async {
    await paint(tester, view(), []);
    await tester.tap(find.text('Locked 0'));
    await tester.pumpAndSettle();
    expect(find.text('No locked VTXOs.'), findsOneWidget);
    expect(find.text('No VTXOs yet'), findsNothing);
  });

  testWidgets('details use observed data and Renew emits one immutable ID', (
    tester,
  ) async {
    final calls = <List<String>>[];
    final id = 'a3f9c2e8${'0' * 50}71e0:1';
    await paint(
      tester,
      view(values: [coin(id, anchor: 'actual-anchor')]),
      calls,
    );
    await open(tester, id);
    expect(find.text('VTXO details'), findsOneWidget);
    expect(details(tester), containsPair('Expires', 'Block 500'));
    expect(details(tester), containsPair('Blocks left', '400 (~3 days)'));
    expect(details(tester).keys, isNot(contains('Created')));
    expect(details(tester), containsPair('VTXO ID', 'a3f9c2e8…71e0:1'));
    expect(details(tester), containsPair('Anchor point', 'actual-anchor'));
    final idRow = tester
        .widgetList<BullDetailsTableItem>(
          find.descendant(
            of: find.byType(BullDetailsTable),
            matching: find.byType(BullDetailsTableItem),
          ),
        )
        .singleWhere((item) => item.label == 'VTXO ID');
    expect(idRow.copyValue, id);
    expect(
      find.text(
        'Less than 1008 blocks left. Renew now so this VTXO does not expire.',
      ),
      findsOneWidget,
    );
    expect(renew(tester).disabled, false);
    expect(calls, isEmpty);
    renew(tester).onPressed();
    expect(calls, [
      [id],
    ]);
    expect(() => calls.single.add('not-selected'), throwsUnsupportedError);
  });

  testWidgets('spent VTXOs are never listed or counted', (tester) async {
    await paint(
      tester,
      view(
        values: [
          coin('live', expiry: 5000),
          coin('gone', state: ArkVtxoState.spent, expiry: 5000),
        ],
      ),
      [],
    );
    expect(row('live'), findsOneWidget);
    expect(row('gone'), findsNothing);
    expect(find.text('All 1'), findsOneWidget);
  });

  testWidgets('a VTXO being renewed shows as Locked until it is renewed', (
    tester,
  ) async {
    await paint(
      tester,
      view(
        values: [coin('renewed', expiry: 5000)],
        operations: [
          ArkOperation(
            id: 'renewal',
            kind: ArkOperationKind.renewal,
            status: ArkOperationStatus.pending,
            chainSource: Uri.parse('http://localhost:3000'),
            configGeneration: 1,
            actualIds: const ['renewed'],
          ),
        ],
      ),
      [],
    );
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Locked 1'), findsOneWidget);
    expect(find.text('Active 0'), findsOneWidget);
    await tester.tap(row('renewed'));
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsWidgets);
    expect(find.textContaining('Renewal started'), findsNothing);
    // Already renewing: locked until its round, nothing to renew again.
    expect(
      tester
          .widgetList<BullDetailsTableItem>(find.byType(BullDetailsTableItem))
          .singleWhere((item) => item.label == 'State')
          .displayValue,
      'Locked',
    );
    expect(find.widgetWithText(BullButton, 'Renew'), findsNothing);
  });

  testWidgets('a started renewal returns to all the VTXOs', (tester) async {
    final calls = <List<String>>[];
    await paint(
      tester,
      view(values: [coin('due', expiry: 150)]),
      calls,
      renewStarts: true,
    );
    await tester.tap(row('due'));
    await tester.pumpAndSettle();
    expect(find.text('VTXO details'), findsOneWidget);
    await tester.tap(find.widgetWithText(BullButton, 'Renew'));
    await tester.pumpAndSettle();
    expect(calls, [
      ['due'],
    ]);
    expect(find.text('VTXO details'), findsNothing);
    expect(row('due'), findsOneWidget);
  });

  testWidgets('a cancelled renewal stays on the VTXO details', (tester) async {
    await paint(tester, view(values: [coin('due', expiry: 150)]), []);
    await tester.tap(row('due'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BullButton, 'Renew'));
    await tester.pumpAndSettle();
    expect(find.text('VTXO details'), findsOneWidget);
  });

  testWidgets('exited VTXOs and those under an exit are not listed', (
    tester,
  ) async {
    await paint(
      tester,
      view(
        values: [
          coin('live', expiry: 5000),
          coin('exited', state: ArkVtxoState.exited, expiry: 5000),
          coin('exiting', state: ArkVtxoState.locked, expiry: 5000),
        ],
        exits: [
          ArkExit(
            id: 'exiting',
            amount: Sats.fromInt(1234),
            status: ArkExitStatus.pending,
          ),
        ],
      ),
      [],
    );
    expect(row('live'), findsOneWidget);
    expect(row('exited'), findsNothing);
    expect(row('exiting'), findsNothing);
    expect(find.text('All 1'), findsOneWidget);
  });

  testWidgets('an active VTXO dates its creation and explains renewal', (
    tester,
  ) async {
    await paint(
      tester,
      view(
        values: [coin('boarded', expiry: 5000)],
        movements: [
          ArkMovement(
            id: 'board',
            kind: ArkMovementKind.board,
            status: ArkMovementStatus.successful,
            createdAt: DateTime(2026, 11, 20, 13, 30),
            outputVtxoIds: const ['boarded'],
          ),
        ],
      ),
      [],
    );
    await open(tester, 'boarded');
    expect(
      details(tester),
      containsPair('Created', 'November 20, 2026 1:30\u202fPM'),
    );
    expect(
      find.text(
        'Ark funds have an expiry date. The app renews them for you '
        'automatically, as long as you open it during the last 7 days. You '
        'can also renew them yourself at any time, for a fee.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('locked and expired details offer no renewal', (tester) async {
    final calls = <List<String>>[];
    final values = [
      coin('locked', state: ArkVtxoState.locked),
      coin('round', pendingRound: true),
      coin('expired', expiry: 100),
    ];
    for (final id in ['locked', 'round', 'expired']) {
      await paint(tester, view(values: values), calls);
      await open(tester, id);
      expect(renewButton(), findsNothing);
      expect(
        find.text('This VTXO has expired and can’t be renewed.'),
        id == 'expired' ? findsOneWidget : findsNothing,
      );
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
    }
    expect(calls, isEmpty);
  });

  final invalid = {
    'stale': view(stale: true),
    'incomplete': view(completeness: ArkSectionCompleteness.incomplete),
    'missing tip': view(tip: null),
    'recovery unknown': view(recovery: ArkRecoveryStatus.unknown),
    'delegated': view(renewal: ArkRenewalStatus.delegated),
  };
  for (final entry in invalid.entries) {
    testWidgets('${entry.key} disables Renew and voids its old callback', (
      tester,
    ) async {
      final calls = <List<String>>[];
      await paint(tester, view(), calls);
      await open(tester, 'shared');
      final oldRenew = renew(tester).onPressed;
      await paint(tester, entry.value, calls);
      if (renewButton().evaluate().isNotEmpty) {
        expect(renew(tester).disabled, true);
      }
      oldRenew();
      expect(calls, isEmpty);
    });
  }

  testWidgets('account replacement closes details and voids old callbacks', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await paint(tester, view(), calls);
    final oldOpen = tester.widget<GestureDetector>(row('shared')).onTap;
    await open(tester, 'shared');
    final oldRenew = renew(tester).onPressed;
    await paint(tester, view(owner: other), calls);
    expect(find.text('VTXO details'), findsNothing);
    expect(find.text('Total in Ark'), findsOneWidget);
    oldRenew();
    oldOpen?.call();
    await tester.pumpAndSettle();
    expect(find.text('VTXO details'), findsNothing);
    expect(calls, isEmpty);
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
      await open(tester, 'shared');
      expect(find.text('VTXO details'), findsOneWidget);
      await paint(tester, view(values: values), calls);
      expect(find.text('VTXO details'), findsNothing);
    }
    expect(calls, isEmpty);
  });

  testWidgets('back from details returns to the list, not out of the screen', (
    tester,
  ) async {
    await paint(tester, view(), []);
    await open(tester, 'shared');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('VTXO details'), findsNothing);
    expect(find.text('Total in Ark'), findsOneWidget);
    await open(tester, 'shared');
    tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack?.call();
    await tester.pumpAndSettle();
    expect(find.text('Total in Ark'), findsOneWidget);
  });

  testWidgets('only a current complete empty inventory displays empty', (
    tester,
  ) async {
    final calls = <List<String>>[];
    var boards = 0;
    await paint(tester, view(values: []), calls, onBoard: () => boards++);
    expect(find.text('No VTXOs yet'), findsOneWidget);
    expect(find.text('Bitcoin you receive shows up here.'), findsOneWidget);
    await tester.tap(find.text('Board to Ark'));
    expect(boards, 1);
    await paint(tester, view(values: []), calls);
    expect(find.text('Board to Ark'), findsNothing);
    for (final (snapshot, note) in [
      (view(values: [], stale: true), 'Last observed data'),
      (
        view(values: [], completeness: ArkSectionCompleteness.incomplete),
        'Some VTXO details are still loading',
      ),
    ]) {
      await paint(tester, snapshot, calls);
      expect(find.text('No VTXOs yet'), findsNothing);
      // A grey line that says why, never a bare "Unavailable" bar.
      expect(find.textContaining(note), findsOneWidget);
      expect(find.byType(BullInfoBar), findsNothing);
    }
    expect(calls, isEmpty);
  });

  testWidgets('a renewal under way leaves the data shown as observed', (
    tester,
  ) async {
    await paint(
      tester,
      view(
        renewal: ArkRenewalStatus.delegated,
        values: [
          coin('renewing', expiry: 5000, pendingRound: true),
          coin('live', expiry: 5000),
        ],
      ),
      [],
    );
    expect(find.text('Unavailable'), findsNothing);
    expect(find.byType(BullInfoBar), findsNothing);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('2,468 sats'), findsOneWidget);
  });

  testWidgets('the empty state sits in the middle of the space under filters', (
    tester,
  ) async {
    await paint(tester, view(values: []), [], onBoard: () {});
    final title = find.text('No VTXOs yet');
    final content = tester.getRect(
      find.ancestor(of: title, matching: find.byType(Column)).first,
    );
    final area = find
        .ancestor(of: title, matching: find.byType(Center))
        .evaluate()
        .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)))
        .reduce((a, b) => a.height >= b.height ? a : b);
    expect(area.top, greaterThan(tester.getRect(find.text('All 0')).bottom));
    expect(content.center.dy, moreOrLessEquals(area.center.dy, epsilon: 1));
  });
}
