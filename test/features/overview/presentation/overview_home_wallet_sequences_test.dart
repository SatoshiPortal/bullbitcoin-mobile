import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart' show Environment, Swap, SwapStatus, SwapType;
import 'package:sync/sync.dart' show WalletKey;

import '../support/overview_home_harness.dart';

OverviewHomeRow rowOf(OverviewHomeState state, String id) =>
    state.rows.singleWhere((row) => row.selection.key.id == id);

Swap heldSwap(String id) => Swap.lnSend(
  id: id,
  keyIndex: 0,
  type: SwapType.liquidToLightning,
  status: SwapStatus.pending,
  environment: Environment.regtest,
  creationTime: DateTime.utc(2026, 1, 1),
  sendWalletId: 'liquid',
  paymentAddress: 'lq1example',
  invoice: 'lnbc1example',
  paymentAmount: 10000,
);

void main() {
  final bitcoinKey = WalletKey(
    id: 'btc:regtest',
    network: BitcoinNetwork.regtest,
  );
  final liquidKey = WalletKey(
    id: 'liquid:regtest',
    network: LiquidNetwork.regtest,
  );

  test(
    'a start marks only its row and a finish clears only its wallet',
    () async {
      final h = OverviewHomeHarness();
      addTearDown(h.close);
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', balanceSat: 100),
          homeWallet(
            'liquid:regtest',
            network: LiquidNetwork.regtest,
            balanceSat: 250,
          ),
        ]),
      );
      await flushEvents();

      final reads = h.swaps.reads;
      final backups = h.backupReadsStarted;
      final snapshots = h.source.snapshots;
      h.started.add((key: bitcoinKey, runId: 1));
      h.started.add((key: liquidKey, runId: 2));
      await flushEvents();

      var state = h.controller.current;
      expect(rowOf(state, 'btc:regtest').isSyncing, isTrue);
      expect(rowOf(state, 'liquid:regtest').isSyncing, isTrue);
      // A start only moves the indicator: no swap read, no backup read, no
      // membership re-read and no money change of its own.
      expect(h.swaps.reads, reads);
      expect(h.backupReadsStarted, backups);
      expect(h.source.snapshots, snapshots);
      expect(state.totalSat, 350);

      h.finished.add(bitcoinKey);
      await flushEvents();

      state = h.controller.current;
      expect(rowOf(state, 'btc:regtest').isSyncing, isFalse);
      expect(rowOf(state, 'liquid:regtest').isSyncing, isTrue);
      // One finish reads the swaps once and never touches B's pass or balance.
      expect(h.swaps.reads, reads + 1);
      expect(h.backupReadsStarted, backups + 1);
      expect(h.source.snapshots, snapshots);
      expect(rowOf(state, 'liquid:regtest').balanceSat, 250);
      expect(state.rows.map((row) => row.selection.key), [
        bitcoinKey,
        liquidKey,
      ]);
    },
  );

  test('a late finish keeps the failed round warning until a newer round clears it', () async {
    final h = OverviewHomeHarness();
    addTearDown(h.close);
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc:regtest', balanceSat: 100),
      ]),
    );
    await flushEvents();

    h.sync.outcome = HomeSyncOutcome.failed;
    await h.controller.refresh();
    await flushEvents();
    expect(
      h.controller.current.loadFailure,
      OverviewLoadFailure.balancesMayBeStale,
    );
    expect(h.controller.current.isRefreshing, isFalse);

    // Each wallet's datasource fires its finish from a `finally`, so one
    // arrives right after a failed round. It must not clear the warning.
    h.finished.add(bitcoinKey);
    await flushEvents();
    expect(
      h.controller.current.loadFailure,
      OverviewLoadFailure.balancesMayBeStale,
    );
    expect(h.controller.current.rows, hasLength(1));
    expect(h.controller.current.totalSat, 100);

    h.sync.outcome = HomeSyncOutcome.completed;
    await h.controller.refresh();
    await flushEvents();
    expect(h.controller.current.loadFailure, isNull);
    expect(h.controller.current.isRefreshing, isFalse);
  });

  test('an empty catalogue only onboards once its reload settled', () async {
    final h = OverviewHomeHarness();
    addTearDown(h.close);
    await h.mount();

    h.source.publish(emptySnapshot);
    await flushEvents();
    expect(h.controller.current.isEmpty, isTrue);
    expect(h.controller.current.isLoading, isFalse);

    final states = <bool>[];
    void listener() => states.add(h.controller.current.isEmpty);
    h.controller.addListener(listener);
    addTearDown(() => h.controller.removeListener(listener));

    // The reload after a recovery opens while it is still reading. It must not
    // report the previous "no wallets" mid-transition.
    h.source.publish(snapshot(OverviewCatalogueStatus.replacing, const []));
    await flushEvents();
    expect(h.controller.current.isEmpty, isFalse);
    expect(h.controller.current.isLoading, isTrue);
    expect(states, isNot(contains(true)));

    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc:regtest', balanceSat: 10),
      ]),
    );
    await flushEvents();
    expect(h.controller.current.isEmpty, isFalse);
    expect(h.controller.current.rows, hasLength(1));

    // A reload that finds no wallet again is onboarding once it settled.
    h.source.publish(emptySnapshot);
    await flushEvents();
    expect(h.controller.current.isEmpty, isTrue);
    expect(states.last, isTrue);
  });

  test('a round overlapping revocation and re-admission cannot publish its outcome', () async {
    final h = OverviewHomeHarness();
    addTearDown(h.close);
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('old:regtest', balanceSat: 100),
      ]),
    );
    await flushEvents();

    h.sync.autoComplete = false;
    final stale = h.controller.refresh();
    await flushEvents();
    expect(h.sync.pending, 1);
    expect(h.controller.current.isRefreshing, isTrue);
    final reads = h.swaps.reads;

    h.source.publish(snapshot(OverviewCatalogueStatus.revoked, const []));
    await flushEvents();
    expect(h.controller.current.rows, isEmpty);
    expect(h.controller.current.isRefreshing, isFalse);
    expect(h.controller.current.isLoading, isTrue);

    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('new:regtest', balanceSat: 70),
      ]),
    );
    await flushEvents();
    expect(h.controller.current.totalSat, 70);

    // The round started against the previous catalogue finishes late.
    h.sync.completeNext(HomeSyncOutcome.failed);
    await stale;
    await flushEvents();
    expect(h.controller.current.rows.single.selection.key.id, 'new:regtest');
    expect(h.controller.current.isRefreshing, isFalse);
    expect(h.controller.current.loadFailure, isNull);
    expect(h.controller.current.ongoingSwaps, isEmpty);
    expect(h.swaps.reads, reads);

    // A new round on the admitted catalogue still runs normally.
    h.sync.autoComplete = true;
    h.sync.outcome = HomeSyncOutcome.completed;
    await h.controller.refresh();
    await flushEvents();
    expect(h.sync.triggers, [SyncTrigger.user, SyncTrigger.user]);
    expect(h.controller.current.isRefreshing, isFalse);
    expect(h.controller.current.loadFailure, isNull);
  });

  test(
    'a failed swap read keeps the notices until a confirmed empty read',
    () async {
      final h = OverviewHomeHarness();
      addTearDown(h.close);
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', balanceSat: 100),
        ]),
      );
      await flushEvents();

      h.swaps.result = Ok([heldSwap('held')]);
      h.finished.add(bitcoinKey);
      await flushEvents();
      expect(h.controller.current.ongoingSwaps.single.id, 'held');

      // A failed read is not evidence that no swap is in progress.
      h.swaps.result = const Err(OngoingSwapsUnavailableFailure());
      h.finished.add(bitcoinKey);
      await flushEvents();
      expect(h.controller.current.ongoingSwaps.single.id, 'held');

      // Only a confirmed empty answer clears the notices.
      h.swaps.result = const Ok([]);
      h.finished.add(bitcoinKey);
      await flushEvents();
      expect(h.controller.current.ongoingSwaps, isEmpty);
    },
  );

  test(
    'pass completion applies incoming swaps until a catalogue replacement',
    () async {
      final h = OverviewHomeHarness()..swaps.manual = true;
      addTearDown(h.close);
      await h.mount();
      h.swaps.complete(const Ok([]));
      await flushEvents();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', balanceSat: 100),
        ]),
      );
      await flushEvents();

      // Unchanged membership: the pass's own read is authoritative.
      h.swaps.manual = false;
      h.swaps.result = Ok([heldSwap('incoming')]);
      await h.controller.refresh();
      await flushEvents();
      expect(h.controller.current.ongoingSwaps.single.id, 'incoming');

      // Replaced catalogue: the pass is retired while its read is still open.
      h.swaps
        ..manual = true
        ..result = const Ok([]);
      h.sync.autoComplete = false;
      final pass = h.controller.refresh();
      await flushEvents();
      final reads = h.swaps.reads;
      h.sync.completeNext(HomeSyncOutcome.failed);
      await flushEvents();
      expect(h.swaps.reads, reads + 1);

      h.source.publish(snapshot(OverviewCatalogueStatus.replacing, const []));
      await flushEvents();
      h.swaps.completeAt(0, Ok([heldSwap('stale')]));
      await pass;
      await flushEvents();

      expect(h.controller.current.ongoingSwaps, isEmpty);
      expect(h.controller.current.loadFailure, isNull);
      expect(h.controller.current.rows, isEmpty);
      expect(h.controller.current.isRefreshing, isFalse);
    },
  );
}
