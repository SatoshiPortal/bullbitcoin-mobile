import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_exit_steps.dart';
import 'package:bull_ark/src/ui/ark_exits_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDetailsTable,
        BullDetailsTableItem,
        BullBadge,
        BullPaymentTransition,
        BullPaymentViewSwitch,
        BullRefreshIndicator,
        SizedBox,
        ValueKey,
        VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account;

ArkExit exitRow({
  String id = 'shared',
  ArkExitStatus status = ArkExitStatus.claimable,
  int? height = 99,
  String? txid = 'observed-txid',
}) => ArkExit(
  id: id,
  amount: Sats.fromInt(1234),
  status: status,
  claimableHeight: height,
  claimTxid: txid,
);
ArkSnapshot view({
  ArkAccountId? owner,
  bool stale = false,
  int? tip = 100,
  ArkRecoveryStatus recovery = ArkRecoveryStatus.complete,
  ArkExitStatus exits = ArkExitStatus.claimable,
  List<ArkExit>? rows,
  bool online = false,
}) => ArkSnapshot(
  account: owner ?? account(),
  revision: 2,
  observedAt: DateTime.utc(2026, 11, 16),
  stale: stale,
  tipHeight: tip,
  recovery: recovery,
  exits: exits,
  exitDetails: rows ?? [exitRow()],
  vtxoCompleteness: ArkSectionCompleteness.unknown,
  serverInfo: online
      ? ArkServerInfo(
          publicKey: 'public-server-key',
          minimumBoard: Sats.fromInt(1200),
          maximumVtxo: Sats.fromInt(800000),
          boardConfirmations: 3,
          roundIntervalSeconds: 10,
          vtxoLifetimeBlocks: 4320,
        )
      : null,
);

class Harness {
  ArkSnapshot snapshot;
  int exits = 0, sends = 0;
  final bool withSend;
  final Sats? waitingForFunds;

  /// The payment animation preference; the tests of the page keep it off.
  final Future<bool> Function()? readAnimations;
  Harness(
    this.snapshot, {
    this.withSend = false,
    this.waitingForFunds,
    this.readAnimations = _off,
  });
  static Future<bool> _off() async => false;
  ArkExitsScreen get screen => ArkExitsScreen(
    snapshot: snapshot,
    onReviewExit: () => exits++,
    onSendOnChain: withSend ? () => sends++ : null,
    waitingForFunds: waitingForFunds,
    readPaymentAnimations: readAnimations,
  );
  bool get untouched => exits == 0;
}

List<BullButton> buttons(WidgetTester tester) =>
    tester.widgetList<BullButton>(find.byType(BullButton)).toList();
BullButton button(WidgetTester tester, String label) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, label));
List<BullDetailsTableItem> items(WidgetTester tester) => [
  for (final table in tester.widgetList<BullDetailsTable>(
    find.byType(BullDetailsTable),
  ))
    ...table.items.whereType<BullDetailsTableItem>(),
];

/// The rows of the exits card.
Finder exitRows() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('exit-row-');
});

Future<void> openDetail(WidgetTester tester, [int index = 0]) async {
  final tile = exitRows().at(index);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pump();
}

/// Pull-to-refresh is the list's refresh entry, as on the app's wallets.
VoidCallback pullToRefresh(WidgetTester tester) {
  final onRefresh = tester
      .widget<BullRefreshIndicator>(find.byType(BullRefreshIndicator))
      .onRefresh;
  return () => onRefresh();
}

void main() {
  testWidgets('exit rows open a detail view without advancing anything', (
    tester,
  ) async {
    final h = Harness(view(rows: [exitRow(status: ArkExitStatus.submitted)]));
    await tester.pumpWidget(app(h.screen));
    expect(find.byType(BullDetailsTable), findsNothing);
    expect(find.text('Claiming'), findsOneWidget);
    await openDetail(tester);
    expect(find.text('observed-txid'), findsOneWidget);
    expect(find.byType(ArkExitSteps), findsOneWidget);
    expect(h.untouched, true);
    expect(find.textContaining('confirmed'), findsNothing);
    expect(find.textContaining('automatically'), findsNothing);
    expect(
      find.text('Claim transaction sent. Waiting for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('claimed exits stay listed as history, grouped as started', (
    tester,
  ) async {
    final claimTxid = 'c' * 64;
    ArkOperation op(String id, ArkOperationKind kind) => ArkOperation(
      id: id,
      kind: kind,
      status: kind == ArkOperationKind.claim
          ? ArkOperationStatus.succeeded
          : ArkOperationStatus.pending,
      chainSource: Uri.parse('http://localhost:3000'),
      configGeneration: 1,
      actualIds: const ['first', 'second'],
      claimRecovery: kind == ArkOperationKind.claim
          ? ArkClaimRecovery(
              txid: claimTxid,
              destination: 'bcrt1qdestination',
              net: Sats.fromInt(1900),
              fee: Sats.fromInt(100),
            )
          : null,
    );
    final snapshot = ArkSnapshot(
      account: account(),
      revision: 2,
      observedAt: DateTime.utc(2026, 11, 16),
      tipHeight: 100,
      // Bark no longer lists an exit once it is claimed.
      exits: ArkExitStatus.none,
      vtxos: [
        for (final id in ['first', 'second'])
          ArkVtxo(
            id: id,
            amount: Sats.fromInt(1000),
            expiryHeight: 500,
            state: ArkVtxoState.exited,
          ),
      ],
      operations: [
        op('start', ArkOperationKind.emergencyExit),
        op('claim', ArkOperationKind.claim),
      ],
    );
    await tester.pumpWidget(app(Harness(snapshot).screen));
    expect(find.text('No emergency exits'), findsNothing);
    // One entry for the two VTXOs exited together, with their total.
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.text('2,000 sats'), findsOneWidget);
    await openDetail(tester);
    expect(find.textContaining(claimTxid.substring(0, 6)), findsWidgets);
  });

  testWidgets('an exit waiting for fees says how much to add', (tester) async {
    final h = Harness(
      view(rows: [exitRow(status: ArkExitStatus.pending)]),
      waitingForFunds: Sats.fromInt(4000),
    );
    await tester.pumpWidget(app(h.screen));
    const message = 'Add at least 4,000 sats to your Secure Bitcoin wallet';
    expect(find.textContaining(message), findsOneWidget);
    await openDetail(tester);
    expect(find.textContaining(message), findsOneWidget);
  });

  testWidgets('nothing missing shows no funds message', (tester) async {
    final h = Harness(view(rows: [exitRow(status: ArkExitStatus.pending)]));
    await tester.pumpWidget(app(h.screen));
    expect(find.textContaining('Secure Bitcoin wallet'), findsNothing);
  });

  testWidgets('detail back returns to the list instead of leaving', (
    tester,
  ) async {
    final h = Harness(view());
    await tester.pumpWidget(app(h.screen));
    await openDetail(tester);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Done'), findsNothing);
    expect(find.text('Start emergency exit'), findsOneWidget);
    expect(h.untouched, true);
  });

  testWidgets(
    'refresh is passive until requested and cannot cross an account replacement',
    (tester) async {
      var refreshes = 0;
      final h = Harness(view());
      await tester.pumpWidget(
        app(
          ArkExitsScreen(
            snapshot: h.snapshot,
            onReviewExit: () {},
            onRefresh: () => refreshes++,
          ),
        ),
      );
      expect(refreshes, 0);
      final refresh = pullToRefresh(tester);
      refresh();
      expect(refreshes, 1);
      final original = account();
      await tester.pumpWidget(
        app(
          ArkExitsScreen(
            snapshot: view(
              owner: ArkAccountId(
                parent: original.parent,
                network: original.network,
                serverIdentity: 'other',
              ),
            ),
            onReviewExit: () {},
          ),
        ),
      );
      refresh();
      expect(refreshes, 1);
    },
  );
  testWidgets('read-only detail shows explicit sats and exact copy metadata', (
    tester,
  ) async {
    final h = Harness(view());
    await tester.pumpWidget(app(h.screen));
    expect(h.untouched, true);
    await openDetail(tester);
    expect(find.text('1,234 sats'), findsWidgets);
    final txid = items(tester)
        .singleWhere((i) => i.label == 'Claim transaction');
    expect(txid.displayValue, 'observed-txid');
    expect(txid.copyValue, txid.displayValue);
    expect(find.text('Claimable'), findsWidgets);
    expect(h.untouched, true);
  });
  testWidgets(
    'old callbacks cannot cross account/server with identical row ID',
    (tester) async {
      final a = Harness(view());
      await tester.pumpWidget(app(a.screen));
      final old = [for (final b in buttons(tester)) b.onPressed];
      await openDetail(tester);
      old.addAll([for (final b in buttons(tester)) b.onPressed]);
      final original = account();
      final b = Harness(
        view(
          owner: ArkAccountId(
            parent: original.parent,
            network: original.network,
            serverIdentity: 'different-server',
          ),
        ),
      );
      await tester.pumpWidget(app(b.screen));
      // The replaced account closes the detail view.
      expect(find.text('Done'), findsNothing);
      for (final callback in old) {
        callback();
      }
      expect(a.untouched, true);
      expect(b.untouched, true);
    },
  );
  for (final recovery in [
    ArkRecoveryStatus.unknown,
    ArkRecoveryStatus.incomplete,
    ArkRecoveryStatus.failed,
  ]) {
    testWidgets(
      'fresh protective review remains available with recovery $recovery',
      (tester) async {
        final h = Harness(view(recovery: recovery));
        await tester.pumpWidget(app(h.screen));
        for (final button in buttons(tester)) {
          expect(button.disabled, false);
          button.onPressed();
        }
        expect(h.exits, 1);
      },
    );
  }
  for (final invalid in [
    view(stale: true),
    view(tip: null),
    view(exits: ArkExitStatus.unknown),
    view(exits: ArkExitStatus.failed),
  ]) {
    testWidgets(
      'old and rendered review callbacks refuse unavailable exit observation ${invalid.stale}/${invalid.tipHeight}/${invalid.exits}',
      (tester) async {
        final h = Harness(view());
        await tester.pumpWidget(app(h.screen));
        final old = [for (final b in buttons(tester)) b.onPressed];
        await openDetail(tester);
        old.addAll([for (final b in buttons(tester)) b.onPressed]);
        h.snapshot = invalid;
        await tester.pumpWidget(app(h.screen));
        expect(find.text('1,234 sats'), findsOneWidget);
        for (final callback in old) {
          callback();
        }
        // Done only closes the detail; every action stays refused.
        for (final button in buttons(tester).where((b) => b.label != 'Done')) {
          expect(button.disabled, true);
          button.onPressed();
        }
        await tester.tap(find.byTooltip('Back'));
        await tester.pump();
        expect(find.text('1,234 sats'), findsOneWidget);
        for (final button in buttons(tester)) {
          expect(button.disabled, true);
          button.onPressed();
        }
        expect(h.untouched, true);
      },
    );
  }
  testWidgets('VTXOs exited together show as one exit', (tester) async {
    final h = Harness(
      ArkSnapshot(
        account: account(),
        revision: 2,
        observedAt: DateTime.utc(2026, 11, 16),
        tipHeight: 100,
        exits: ArkExitStatus.pending,
        exitDetails: [
          exitRow(id: 'first', status: ArkExitStatus.claimable, height: 90),
          exitRow(id: 'second', status: ArkExitStatus.pending, height: null),
          exitRow(id: 'alone', status: ArkExitStatus.claimable),
        ],
        operations: [
          ArkOperation(
            id: 'started-together',
            kind: ArkOperationKind.emergencyExit,
            status: ArkOperationStatus.pending,
            chainSource: Uri.parse('http://localhost:3000'),
            configGeneration: 1,
            actualIds: const ['first', 'second'],
          ),
        ],
      ),
    );
    await tester.pumpWidget(app(h.screen));
    // Two blocks: the pair and the one started on its own.
    expect(exitRows(), findsNWidgets(2));
    expect(find.text('2,468 sats'), findsOneWidget);
    expect(find.text('2 VTXOs'), findsOneWidget);
    // The pair is as far along as its slower member.
    expect(
      find.bySemanticsLabel('2,468 sats, Pending. Show details'),
      findsOneWidget,
    );
    // Tapping the pair opens it as one exit.
    await tester.tap(find.text('2,468 sats'));
    await tester.pump();
    expect(find.byType(ArkExitSteps), findsOneWidget);
    expect(find.text('2,468 sats'), findsWidgets);
  });

  testWidgets('a claimable exit is claimed by the app: nothing to press', (
    tester,
  ) async {
    final h = Harness(view());
    await tester.pumpWidget(app(h.screen));
    await openDetail(tester);
    expect(find.text('Review claim'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('by itself while it’s open'), findsOneWidget);
  });

  testWidgets('a claim already sent reads Claiming before Bark catches up', (
    tester,
  ) async {
    final h = Harness(
      ArkSnapshot(
        account: account(),
        revision: 2,
        observedAt: DateTime.utc(2026, 11, 16),
        tipHeight: 100,
        exits: ArkExitStatus.claimable,
        exitDetails: [exitRow()],
        operations: [
          ArkOperation(
            id: 'claim',
            kind: ArkOperationKind.claim,
            status: ArkOperationStatus.pending,
            chainSource: Uri.parse('http://localhost:3000'),
            configGeneration: 1,
            actualIds: const ['shared'],
          ),
        ],
      ),
    );
    await tester.pumpWidget(app(h.screen));
    expect(find.text('Claiming'), findsOneWidget);
    expect(find.text('Claimable'), findsNothing);
    await openDetail(tester);
    expect(
      find.text('Claim transaction sent. Waiting for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('offline shows the last observed exits with a grey note', (
    tester,
  ) async {
    // Last observed: no exits. Offline keeps showing that, never an error.
    await tester.pumpWidget(
      app(
        Harness(view(rows: [], stale: true, exits: ArkExitStatus.none)).screen,
      ),
    );
    expect(find.text('No emergency exits'), findsOneWidget);
    expect(find.textContaining('Last observed data'), findsOneWidget);
    expect(find.text('Couldn’t confirm your emergency exits'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    // Last observed: an exit. Offline keeps listing it.
    await tester.pumpWidget(
      app(Harness(view(stale: true, exits: ArkExitStatus.pending)).screen),
    );
    expect(exitRows(), findsWidgets);
    expect(find.text('No emergency exits'), findsNothing);
    // A summary that saw an exit without its rows claims neither state.
    for (final partial in [
      view(rows: [], exits: ArkExitStatus.unknown),
      view(rows: [], exits: ArkExitStatus.pending),
    ]) {
      await tester.pumpWidget(app(Harness(partial).screen));
      expect(find.text('No emergency exits'), findsNothing);
      expect(find.text('Couldn’t confirm your emergency exits'), findsNothing);
    }
  });
  testWidgets(
    'missing height and txid remain unavailable without copy default',
    (tester) async {
      await tester.pumpWidget(
        app(Harness(view(rows: [exitRow(height: null, txid: null)])).screen),
      );
      await openDetail(tester);
      // Nothing to copy and no invented height.
      expect(
        items(tester).where((i) => i.label == 'Claim transaction'),
        isEmpty,
      );
      expect(find.textContaining('Claimable at block'), findsNothing);
    },
  );
  testWidgets('a long claim transaction id shows on one line, copies whole', (
    tester,
  ) async {
    const txid =
        '9f2c4b7a1e0d3c5b8a6f4e2d1c0b9a8f7e6d5c4b3a291807f6e5d4c3b2a19087';
    await tester.pumpWidget(
      app(
        Harness(
          view(
            rows: [exitRow(status: ArkExitStatus.claimed, txid: txid)],
          ),
        ).screen,
      ),
    );
    await openDetail(tester);
    expect(find.text('9f2c4b7a1e0d…b2a19087'), findsOneWidget);
    expect(find.text(txid), findsNothing);
    final row = items(tester)
        .singleWhere((item) => item.label == 'Claim transaction');
    expect(row.copyValue, txid);
  });
  testWidgets('an unrolled exit waits out its delay, counting blocks', (
    tester,
  ) async {
    final h = Harness(
      view(
        exits: ArkExitStatus.pending,
        rows: [exitRow(status: ArkExitStatus.pending, height: 244)],
      ),
    );
    await tester.pumpWidget(app(h.screen));
    await openDetail(tester);
    expect(find.text('144 blocks left'), findsOneWidget);
    expect(find.textContaining('block 244'), findsNothing);
    final steps = tester.widget<ArkExitSteps>(find.byType(ArkExitSteps)).steps;
    expect(steps.map((s) => s.state), [
      ArkExitStepState.done,
      ArkExitStepState.done,
      ArkExitStepState.current,
      ArkExitStepState.upcoming,
    ]);
    expect(find.text('Exit transactions completed'), findsOneWidget);
    expect(find.text('Continue exit'), findsNothing);
  });
  testWidgets('an exit still unrolling says the app moves it forward', (
    tester,
  ) async {
    final h = Harness(
      view(
        exits: ArkExitStatus.pending,
        rows: [exitRow(status: ArkExitStatus.pending, height: null)],
      ),
    );
    await tester.pumpWidget(app(h.screen));
    await openDetail(tester);
    final steps = tester.widget<ArkExitSteps>(find.byType(ArkExitSteps)).steps;
    expect(steps.map((s) => s.state), [
      ArkExitStepState.done,
      ArkExitStepState.current,
      ArkExitStepState.upcoming,
      ArkExitStepState.upcoming,
    ]);
    // The app moves a started exit forward by itself: nothing to press.
    expect(find.text('Continue exit'), findsNothing);
    expect(
      find.textContaining('broadcasts the next transactions by itself'),
      findsOneWidget,
    );
  });
  testWidgets('stale pending exit does not count blocks from an old tip', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Harness(
          view(
            stale: true,
            exits: ArkExitStatus.pending,
            rows: [exitRow(status: ArkExitStatus.pending, height: 244)],
          ),
        ).screen,
      ),
    );
    await openDetail(tester);
    expect(find.textContaining('blocks left'), findsNothing);
    expect(find.text('Waiting for the exit delay to pass.'), findsOneWidget);
    expect(find.textContaining('block 244'), findsNothing);
  });
  testWidgets('failed and unknown exits get no invented stages', (
    tester,
  ) async {
    for (final status in [ArkExitStatus.failed, ArkExitStatus.unknown]) {
      await tester.pumpWidget(app(const SizedBox.shrink()));
      await tester.pumpWidget(
        app(Harness(view(rows: [exitRow(status: status)])).screen),
      );
      await openDetail(tester);
      expect(find.byType(ArkExitSteps), findsNothing);
      expect(
        find.text(
          status == ArkExitStatus.failed
              ? 'This exit needs attention. Refresh, and contact support if it stays this way.'
              : 'The state of this exit is unknown. Refresh to check again.',
        ),
        findsOneWidget,
      );
    }
  });
  group('payment animation view', () {
    Harness animated(ArkExitStatus status, {Future<bool> Function()? read}) =>
        Harness(
          view(rows: [exitRow(status: status)]),
          readAnimations: read,
        );

    testWidgets('opens on the full-screen status, details one tap away', (
      tester,
    ) async {
      final h = animated(ArkExitStatus.pending);
      await tester.pumpWidget(app(h.screen));
      await tester.pump();
      await openDetail(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      expect(find.byType(BullPaymentViewSwitch), findsOneWidget);
      expect(find.byType(ArkExitSteps), findsNothing);
      expect(find.text('Done'), findsNothing);

      await tester.tap(find.text('Details'));
      await tester.pump();
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(find.byType(ArkExitSteps), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      // The embedded banner is gone: the animation only has its own view.
      expect(find.byType(BullPaymentViewSwitch), findsOneWidget);

      await tester.tap(find.text('Status'));
      await tester.pump();
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      expect(find.byType(ArkExitSteps), findsNothing);
    });

    testWidgets('a failed exit has an animation phase, so it has both views', (
      tester,
    ) async {
      final h = animated(ArkExitStatus.failed);
      await tester.pumpWidget(app(h.screen));
      await tester.pump();
      await openDetail(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      expect(find.byType(BullPaymentViewSwitch), findsOneWidget);
    });

    testWidgets('an unknown exit shows its details alone', (tester) async {
      final h = animated(ArkExitStatus.unknown);
      await tester.pumpWidget(app(h.screen));
      await tester.pump();
      await openDetail(tester);
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(find.byType(BullPaymentViewSwitch), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('animations off shows the details alone', (tester) async {
      final h = animated(ArkExitStatus.pending, read: () async => false);
      await tester.pumpWidget(app(h.screen));
      await tester.pump();
      await openDetail(tester);
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(find.byType(BullPaymentViewSwitch), findsNothing);
      expect(find.byType(ArkExitSteps), findsOneWidget);
    });

    testWidgets('an unread preference shows details, then the status', (
      tester,
    ) async {
      final read = Completer<bool>();
      final h = animated(ArkExitStatus.pending, read: () => read.future);
      await tester.pumpWidget(app(h.screen));
      await openDetail(tester);
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(find.byType(BullPaymentViewSwitch), findsNothing);
      expect(find.byType(ArkExitSteps), findsOneWidget);

      read.complete(true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      expect(find.byType(BullPaymentViewSwitch), findsOneWidget);
    });

    testWidgets('a failing preference read keeps animations on', (
      tester,
    ) async {
      final h = animated(
        ArkExitStatus.pending,
        read: () async => throw StateError('unreadable'),
      );
      await tester.pumpWidget(app(h.screen));
      await tester.pump();
      await openDetail(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
    });

    testWidgets('back closes the detail once, from either view', (
      tester,
    ) async {
      final h = animated(ArkExitStatus.pending);
      await tester.pumpWidget(app(h.screen));
      await tester.pump();

      await openDetail(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(BullPaymentTransition), findsNothing);
      expect(find.text('Start emergency exit'), findsOneWidget);

      await openDetail(tester);
      await tester.tap(find.text('Details'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ArkExitSteps), findsNothing);
      expect(find.text('Start emergency exit'), findsOneWidget);
      // Reopened, the exit opens on its status again.
      await openDetail(tester);
      expect(find.byType(BullPaymentTransition), findsOneWidget);
      expect(h.untouched, true);
    });
  });
  testWidgets('claimed exit offers Done back to the list', (tester) async {
    final h = Harness(view(rows: [exitRow(status: ArkExitStatus.claimed)]));
    await tester.pumpWidget(app(h.screen));
    await openDetail(tester);
    expect(find.text('Funds claimed on-chain.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(find.byType(ArkExitSteps), findsNothing);
    expect(h.untouched, true);
  });
  testWidgets('exit rows and steps are named in the semantics tree', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        Harness(
          view(rows: [exitRow(status: ArkExitStatus.pending, height: null)]),
        ).screen,
      ),
    );
    expect(
      find.bySemanticsLabel('1,234 sats, Pending. Show details'),
      findsOneWidget,
    );
    await openDetail(tester);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Unrolling exit transactions, In progress'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
  testWidgets('send on-chain link is named and only shown when wired', (
    tester,
  ) async {
    await tester.pumpWidget(app(Harness(view()).screen));
    expect(find.text('Send on-chain'), findsNothing);
    final h = Harness(view(), withSend: true);
    await tester.pumpWidget(app(h.screen));
    await tester.tap(find.text('Send on-chain'));
    expect(h.sends, 1);
    expect(h.untouched, true);
  });
  testWidgets('the server banner shows whether the server answers', (
    tester,
  ) async {
    await tester.pumpWidget(app(Harness(view()).screen));
    expect(find.text('Ark server is offline'), findsOneWidget);
    await tester.pumpWidget(app(Harness(view(online: true)).screen));
    expect(find.text('Ark server is online'), findsOneWidget);
  });
  testWidgets('hidden amounts stay hidden in rows and detail', (tester) async {
    await tester.pumpWidget(
      app(Harness(view()).screen, amountPreferences: null),
    );
    expect(find.text('1,234 sats'), findsNothing);
    await openDetail(tester);
    expect(find.text('1,234 sats'), findsNothing);
    expect(find.textContaining('1,234'), findsNothing);
  });
  testWidgets(
    'all typed statuses are explicitly localized in English and French',
    (tester) async {
      final rows = [
        for (final status in ArkExitStatus.values)
          exitRow(id: status.name, status: status),
      ];
      for (final language in ['en', 'fr']) {
        await tester.pumpWidget(
          app(Harness(view(rows: rows)).screen, language: language),
        );
        final statuses = tester
            .widgetList<BullBadge>(find.byType(BullBadge))
            .map((badge) => badge.label)
            .toSet();
        expect(
          statuses,
          language == 'en'
              ? {
                  'Unknown',
                  'No exit observed',
                  'Pending',
                  'Claimable',
                  'Claiming',
                  'Claimed',
                  'Failed',
                }
              : {
                  'Inconnu',
                  'Aucune sortie observée',
                  'En attente',
                  'Récupérable',
                  'Récupération',
                  'Récupéré',
                  'Échec',
                },
        );
      }
    },
  );
  testWidgets('captured callbacks refuse after disposal', (tester) async {
    final h = Harness(view());
    await tester.pumpWidget(app(h.screen));
    final old = [for (final b in buttons(tester)) b.onPressed];
    await openDetail(tester);
    old.addAll([for (final b in buttons(tester)) b.onPressed]);
    await tester.pumpWidget(app(Harness(view()).screen, language: 'fr'));
    // Replace the whole screen type, rather than merely updating its account.
    await tester.pumpWidget(app(const SizedBox.shrink()));
    for (final callback in old) {
      callback();
    }
    expect(h.untouched, true);
  });
}
