import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:preferences/preferences.dart' show PreferencesMissingFailure;
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart' show Environment, Swap, SwapStatus, SwapType;
import 'package:sync/sync.dart' show WalletKey;

import '../support/overview_home_harness.dart';

OverviewHomeRow rowOf(OverviewHomeState state, String id) =>
    state.rows.singleWhere((row) => row.selection.key.id == id);

Swap pendingSwap(String id) => Swap.lnSend(
  id: id,
  keyIndex: 0,
  type: SwapType.liquidToLightning,
  status: SwapStatus.pending,
  environment: Environment.regtest,
  creationTime: DateTime.utc(2026, 1, 1),
  sendWalletId: 'liquid',
  invoice: 'lnbc1example',
  paymentAddress: 'lq1example',
  paymentAmount: 10000,
);

void main() {
  late OverviewHomeHarness h;

  setUp(() => h = OverviewHomeHarness());
  tearDown(() async => h.close());

  final bitcoinKey = WalletKey(
    id: 'btc:regtest',
    network: BitcoinNetwork.regtest,
  );
  final liquidKey = WalletKey(
    id: 'liquid:regtest',
    network: LiquidNetwork.regtest,
  );

  test(
    'backup activation ignores early events and reads current defaults once',
    () async {
      h.automaticBackupStart = false;
      h.manualBackups = true;
      h.physicalBackups.addAll({'first': true, 'second': false});
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('first', isDefault: true, balanceSat: 10),
        ]),
      );
      h.finished.add(bitcoinKey);
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('second', isDefault: true, balanceSat: 10),
        ]),
      );
      await flushEvents();
      expect(h.backupReadsStarted, 0);
      expect(h.physicalBackupReads, isEmpty);

      h.controller.startBackupChecks();
      h.controller.startBackupChecks();
      await flushEvents();
      expect(h.backupReadsStarted, 1);
      expect(h.backupReads, hasLength(1));
      expect(h.physicalBackupReads, ['second']);
      expect(h.sync.triggers, isEmpty);

      h.backupReads.single.complete(true);
      await flushEvents();
      expect(h.controller.current.backupCard, isTrue);
      expect(h.controller.current.backupWarning, isTrue);
    },
  );

  test('backup activation after close is inert', () async {
    h.automaticBackupStart = false;
    await h.controller.close();
    h.controller.startBackupChecks();
    await expectLater(h.controller.verifyBackup(), completes);
    expect(h.backupReadsStarted, 0);
    expect(h.physicalBackupReads, isEmpty);
  });

  test(
    'backup card remains due with zero balance and after dismissal',
    () async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('default', isDefault: true, balanceSat: 0),
        ]),
      );
      await flushEvents();
      expect(h.controller.current.backupCard, isTrue);
      expect(h.controller.current.backupWarning, isFalse);
      h.controller.dismissBackupWarning();
      expect(h.controller.current.backupCard, isTrue);
      expect(h.controller.current.backupWarning, isFalse);
    },
  );

  test('unavailable backup answer falls back to unverified default', () async {
    h.backupAnswer = null;
    h.physicalBackups['default'] = false;
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('default', isDefault: true, balanceSat: 10),
      ]),
    );
    await flushEvents();
    expect(h.controller.current.backupCard, isTrue);
    expect(h.controller.current.backupWarning, isTrue);
  });

  test('pending backup read immediately publishes physical fallback', () async {
    h.backupAnswer = false;
    h.physicalBackups['default'] = false;
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('default', isDefault: true, balanceSat: 10),
      ]),
    );
    await flushEvents();
    expect(h.controller.current.backupCard, isFalse);
    h.manualBackups = true;
    final pending = h.controller.verifyBackup();
    expect(h.controller.current.backupCard, isTrue);
    h.backupReads.last.complete(false);
    await pending;
    expect(h.controller.current.backupCard, isFalse);
  });

  test(
    'replacement resets backup and uses new default physical facts',
    () async {
      h.backupAnswer = null;
      h.physicalBackups.addAll({'first': false, 'second': true});
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('first', isDefault: true, balanceSat: 10),
        ]),
      );
      await flushEvents();
      expect(h.controller.current.backupCard, isTrue);
      h.source.publish(snapshot(OverviewCatalogueStatus.revoked, []));
      await flushEvents();
      expect(h.controller.current.backupCard, isFalse);
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('second', isDefault: true, balanceSat: 10),
        ]),
      );
      await flushEvents();
      expect(h.controller.current.backupCard, isFalse);
    },
  );

  test(
    'superseded refresh cannot publish failure or trigger follow-up work',
    () async {
      await h.mount();
      h.sync.autoComplete = false;
      final first = h.controller.refresh();
      final second = h.controller.refresh();
      await flushEvents();
      h.sync.completeAt(1, HomeSyncOutcome.completed);
      await second;
      final reads = h.swaps.reads;
      final backups = h.backupReadsStarted;
      h.sync.completeAt(0, HomeSyncOutcome.failed);
      await first;
      expect(h.controller.current.loadFailure, isNull);
      expect(h.swaps.reads, reads);
      expect(h.backupReadsStarted, backups);
    },
  );

  test(
    'superseding a refresh awaiting swaps does not expose its outcome',
    () async {
      await h.mount();
      h.swaps.manual = true;
      h.sync.outcome = HomeSyncOutcome.failed;
      final first = h.controller.refresh();
      await flushEvents();
      h.sync.outcome = HomeSyncOutcome.completed;
      final second = h.controller.refresh();
      final observed = h.controller.current.loadFailure;
      await flushEvents();
      h.swaps.complete(const Ok([]));
      h.swaps.complete(const Ok([]));
      await first;
      await second;
      expect(observed, isNull);
      expect(h.controller.current.loadFailure, isNull);
    },
  );

  for (final retired in [
    OverviewCatalogueStatus.revoked,
    OverviewCatalogueStatus.replacing,
  ]) {
    test('retired $retired ignores pending server and late finish', () async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('old', isDefault: true, balanceSat: 10),
        ]),
      );
      await flushEvents();
      h.swapServer.manual = true;
      h.swaps.manual = true;
      final refresh = h.controller.refresh();
      await flushEvents();
      expect(h.swapServer.pending, hasLength(1));
      h.source.publish(snapshot(retired, []));
      await flushEvents();
      final retiredReads = h.swaps.reads;
      final retiredBackups = h.backupReadsStarted;
      h.finished.add(WalletKey(id: 'old', network: BitcoinNetwork.regtest));
      await flushEvents();
      expect(h.swaps.reads, retiredReads);
      expect(h.backupReadsStarted, retiredBackups);
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('new', isDefault: true, balanceSat: 20),
        ]),
      );
      await flushEvents();
      final reads = h.swaps.reads;
      final backups = h.backupReadsStarted;
      h.finished.add(WalletKey(id: 'old', network: BitcoinNetwork.regtest));
      h.swapServer.pending.single.complete(false);
      h.swaps.complete(const Ok([]));
      await refresh;
      await flushEvents();
      expect(h.controller.current.swapServerUnreachable, isFalse);
      expect(h.swaps.reads, reads);
      expect(h.backupReadsStarted, backups);
    });
  }

  test('non-admitted sync finish starts no follow-up work', () async {
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('known', balanceSat: 10),
      ]),
    );
    await flushEvents();
    final reads = h.swaps.reads;
    final backups = h.backupReadsStarted;
    h.finished.add(WalletKey(id: 'other', network: BitcoinNetwork.regtest));
    await flushEvents();
    expect(h.swaps.reads, reads);
    expect(h.backupReadsStarted, backups);
  });

  test('revoked catalogue retires pending refresh outcome', () async {
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('default', isDefault: true, balanceSat: 10),
      ]),
    );
    await flushEvents();
    h.sync.autoComplete = false;
    final refresh = h.controller.refresh();
    h.source.publish(snapshot(OverviewCatalogueStatus.revoked, []));
    await flushEvents();
    final reads = h.swaps.reads;
    final backups = h.backupReadsStarted;
    h.sync.completeAt(0, HomeSyncOutcome.failed);
    await refresh;
    expect(h.controller.current.loadFailure, isNull);
    expect(h.swaps.reads, reads);
    expect(h.backupReadsStarted, backups);
  });

  test(
    'backup verification updates state without other refresh work',
    () async {
      h.backupAnswer = false;
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', balanceSat: 10),
        ]),
      );
      await flushEvents();
      final swapsBefore = h.swaps.reads;
      final checksBefore = h.swapServer.checks;
      expect(h.controller.current.backupCard, isFalse);
      h.backupAnswer = true;
      await h.controller.verifyBackup();
      expect(h.controller.current.backupCard, isTrue);
      expect(h.controller.current.backupWarning, isTrue);
      expect(h.sync.triggers, isEmpty);
      expect(h.swaps.reads, swapsBefore);
      expect(h.swapServer.checks, checksBefore);
    },
  );

  test(
    'controller is a read-only listenable and stays safe after close',
    () async {
      await h.mount();
      var notifications = 0;
      void listener() => notifications++;
      h.controller.addListener(listener);
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', balanceSat: 10),
        ]),
      );
      await flushEvents();
      expect(notifications, greaterThan(0));
      expect(h.controller.value, same(h.controller.current));
      h.controller.removeListener(listener);
      await h.controller.close();
      expect(h.controller.value.totalSat, 10);
      h.controller.addListener(listener);
      h.controller.removeListener(listener);
      await h.controller.verifyBackup();
    },
  );

  test('mount reads a sync pass already in progress', () async {
    h.sync.active = true;
    await h.mount();
    expect(h.controller.current.isSyncPassActive, isTrue);
    h.sync.setActive(false);
    await flushEvents();
    expect(h.controller.current.isSyncPassActive, isFalse);
  });

  test(
    'mount publishes catalogue rows and derives the aggregate total',
    () async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', label: 'Stored', balanceSat: 100),
          homeWallet(
            'liquid:regtest',
            network: LiquidNetwork.regtest,
            balanceSat: 250,
          ),
        ]),
      );
      await flushEvents();

      final state = h.controller.current;
      expect(state.rows, hasLength(2));
      expect(state.rows.map((row) => row.origin), ['btc', 'liquid']);
      expect(state.rows.first.selection.label, 'Stored');
      expect(state.totalSat, 350);
      expect(state.isLoading, isFalse);
      expect(state.isEmpty, isFalse);
    },
  );

  test('an unknown balance stays unknown, never zero', () async {
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc:regtest', balanceSat: 100),
        homeWallet(
          'liquid:regtest',
          network: LiquidNetwork.regtest,
          balanceSat: null,
        ),
      ]),
    );
    await flushEvents();

    final state = h.controller.current;
    expect(state.totalSat, isNull);
    expect(rowOf(state, 'liquid:regtest').balanceSat, isNull);
  });

  test(
    'sync indicators follow started and finished for known wallets only',
    () async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', balanceSat: 100),
          homeWallet(
            'liquid:regtest',
            network: LiquidNetwork.regtest,
            balanceSat: 100,
          ),
        ]),
      );
      await flushEvents();

      h.started.add((key: bitcoinKey, runId: 1));
      await flushEvents();
      expect(rowOf(h.controller.current, 'btc:regtest').isSyncing, isTrue);
      expect(rowOf(h.controller.current, 'liquid:regtest').isSyncing, isFalse);

      h.finished.add(bitcoinKey);
      await flushEvents();
      expect(rowOf(h.controller.current, 'btc:regtest').isSyncing, isFalse);

      // A pass for a wallet this catalogue does not hold must not add a row.
      h.started.add((
        key: WalletKey(id: 'ghost:regtest', network: BitcoinNetwork.regtest),
        runId: 2,
      ));
      await flushEvents();
      expect(h.controller.current.rows, hasLength(2));

      h.sync.setActive(true);
      await flushEvents();
      expect(h.controller.current.isSyncPassActive, isTrue);
      h.sync.setActive(false);
      await flushEvents();
      expect(h.controller.current.isSyncPassActive, isFalse);
    },
  );

  test('revocation and replacement retire rows without onboarding', () async {
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('a:regtest', balanceSat: 10),
      ]),
    );
    await flushEvents();
    expect(h.controller.current.rows, hasLength(1));

    h.source.publish(snapshot(OverviewCatalogueStatus.revoked, const []));
    await flushEvents();
    var state = h.controller.current;
    expect(state.rows, isEmpty);
    expect(state.isLoading, isTrue);
    expect(state.isEmpty, isFalse);

    h.source.publish(snapshot(OverviewCatalogueStatus.replacing, const []));
    await flushEvents();
    expect(h.controller.current.isLoading, isTrue);

    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('b:regtest', balanceSat: 20),
      ]),
    );
    await flushEvents();
    state = h.controller.current;
    expect(state.rows.map((row) => row.selection.key.id), ['b:regtest']);
    expect(state.totalSat, 20);
    expect(state.isLoading, isFalse);
  });

  test('only an empty catalogue is onboarding', () async {
    await h.mount();
    h.source.publish(emptySnapshot);
    await flushEvents();
    expect(h.controller.current.isEmpty, isTrue);
    expect(h.controller.current.isLoading, isFalse);

    h.source.publish(snapshot(OverviewCatalogueStatus.unreadable, const []));
    await flushEvents();
    expect(h.controller.current.isEmpty, isFalse);
    expect(h.controller.current.loadFailure, OverviewLoadFailure.loadFailed);
  });

  test(
    'partial catalogue retains readable rows and reports stale balances',
    () async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.partial, [
          homeWallet('partial', balanceSat: null),
        ]),
      );
      await flushEvents();
      expect(h.controller.current.rows, hasLength(1));
      expect(h.controller.current.totalSat, isNull);
      expect(h.controller.current.isEmpty, isFalse);
      expect(
        h.controller.current.loadFailure,
        OverviewLoadFailure.balancesMayBeStale,
      );
    },
  );

  test('Silent joins the total only while visible and configured', () async {
    // Silent payments are a mainnet/testnet capability.
    h.silent
      ..enabled = true
      ..setUp = true
      ..wallet = silentWallet(700, network: BitcoinNetwork.mainnet);
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc', network: BitcoinNetwork.mainnet, balanceSat: 100),
        homeWallet('liquid', network: LiquidNetwork.mainnet, balanceSat: 250),
      ]),
    );
    await flushEvents();

    var state = h.controller.current;
    expect(state.showSilentCard, isTrue);
    expect(state.silent.balanceSat, 700);
    expect(state.silent.configured, isTrue);
    expect(state.totalSat, 1050);

    h.silent.setUp = false;
    await h.controller.refresh();
    await flushEvents();

    state = h.controller.current;
    expect(state.showSilentCard, isFalse);
    expect(state.totalSat, 350);
  });

  test(
    'a failed Silent refresh hides its previously admitted balance',
    () async {
      h.silent
        ..enabled = true
        ..setUp = true
        ..wallet = silentWallet(700, network: BitcoinNetwork.mainnet);
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc', network: BitcoinNetwork.mainnet, balanceSat: 100),
        ]),
      );
      await flushEvents();
      expect(h.controller.current.silent.balanceSat, 700);
      expect(h.controller.current.totalSat, 800);

      h.silent.failRefresh = true;
      await h.controller.refresh();
      await flushEvents();

      expect(h.controller.current.showSilentCard, isFalse);
      expect(h.controller.current.silent.balanceSat, 0);
      expect(h.controller.current.silent.loading, isFalse);
      expect(h.controller.current.totalSat, 100);
    },
  );

  test('a silent wallet on another environment never joins Home', () async {
    await h.mount();
    h.silent
      ..enabled = true
      ..setUp = true
      ..wallet = silentWallet(700, network: BitcoinNetwork.mainnet);
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc:regtest', balanceSat: 100),
      ]),
    );
    await flushEvents();

    expect(h.controller.current.showSilentCard, isFalse);
    expect(h.controller.current.totalSat, 100);
  });

  test('a stale backup read cannot override the latest answer', () async {
    h.manualBackups = true;
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc:regtest', balanceSat: 100),
      ]),
    );
    await flushEvents();
    expect(h.backupReadsStarted, 1);
    expect(h.controller.current.backupWarning, isFalse);

    await h.controller.refresh();
    await flushEvents();
    expect(h.backupReadsStarted, 2);

    // The later read owns the answer even when the earlier one replies last.
    h.backupReads[1].complete(true);
    await flushEvents();
    expect(h.controller.current.backupWarning, isTrue);

    h.backupReads[0].complete(false);
    await flushEvents();
    expect(h.controller.current.backupWarning, isTrue);
  });

  test(
    'backup warning needs funds and stays dismissed for the session',
    () async {
      await h.mount();
      h.backupAnswer = true;
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', balanceSat: 100),
        ]),
      );
      await flushEvents();
      expect(h.controller.current.backupWarning, isTrue);

      h.controller.dismissBackupWarning();
      expect(h.controller.current.backupWarning, isFalse);

      await h.controller.refresh();
      await flushEvents();
      expect(h.controller.current.backupWarning, isFalse);
    },
  );

  test('a backup warning never sits over an empty wallet', () async {
    await h.mount();
    h.backupAnswer = true;
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc:regtest', balanceSat: 0),
      ]),
    );
    await flushEvents();
    expect(h.controller.current.totalSat, 0);
    expect(h.controller.current.backupWarning, isFalse);
  });

  test(
    'network warnings follow electrum outcomes and the proxy diagnostic',
    () async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc:regtest', balanceSat: 100),
          homeWallet(
            'liquid:regtest',
            network: LiquidNetwork.regtest,
            balanceSat: 100,
          ),
        ]),
      );
      await h.controller.refresh();
      await flushEvents();

      h.emitElectrum(bitcoinKey, isLiquid: false, success: false);
      await flushEvents();
      var warning = h.controller.current.networkWarnings.single;
      expect(warning.reason, ElectrumServerDown.bitcoin);
      expect(warning.action, WalletWarningAction.electrumSettings);

      h.proxyNeedsAttention = true;
      h.emitElectrum(bitcoinKey, isLiquid: false, success: false, runId: 2);
      await flushEvents();
      warning = h.controller.current.networkWarnings.single;
      expect(warning.action, WalletWarningAction.torSettings);

      h.emitElectrum(liquidKey, isLiquid: true, success: false, runId: 3);
      await flushEvents();
      warning = h.controller.current.networkWarnings.single;
      expect(warning.reason, ElectrumServerDown.both);

      h.emitElectrum(bitcoinKey, isLiquid: false, success: true, runId: 4);
      await flushEvents();
      warning = h.controller.current.networkWarnings.single;
      expect(warning.reason, ElectrumServerDown.liquid);

      h.emitElectrum(liquidKey, isLiquid: true, success: true, runId: 5);
      await flushEvents();
      expect(h.controller.current.networkWarnings, isEmpty);
    },
  );

  test(
    'replacement never republishes swaps from the retired catalogue',
    () async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('old', balanceSat: 100),
        ]),
      );
      await flushEvents();
      h.swaps.result = Ok([pendingSwap('old-swap')]);
      h.finished.add(WalletKey(id: 'old', network: BitcoinNetwork.regtest));
      await flushEvents();
      expect(h.controller.current.ongoingSwaps, hasLength(1));

      h.source.publish(snapshot(OverviewCatalogueStatus.revoked, const []));
      await flushEvents();
      expect(h.controller.current.ongoingSwaps, isEmpty);

      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('new', balanceSat: 100),
        ]),
      );
      h.swaps.result = const Err(OngoingSwapsUnavailableFailure());
      h.finished.add(WalletKey(id: 'new', network: BitcoinNetwork.regtest));
      await flushEvents();
      expect(h.controller.current.ongoingSwaps, isEmpty);
    },
  );

  test(
    'replacement retires a pending Electrum diagnostic and its facts',
    () async {
      final oldKey = WalletKey(id: 'old', network: BitcoinNetwork.regtest);
      final newLiquidKey = WalletKey(
        id: 'new-liquid',
        network: LiquidNetwork.regtest,
      );
      h.manualProxy = true;
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('old', balanceSat: 100),
        ]),
      );
      await flushEvents();
      h.emitElectrum(oldKey, isLiquid: false, success: false);
      await flushEvents();
      expect(h.proxyReads, hasLength(1));

      h.source.publish(snapshot(OverviewCatalogueStatus.replacing, const []));
      await flushEvents();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('new', balanceSat: 100),
          homeWallet(
            'new-liquid',
            network: LiquidNetwork.regtest,
            balanceSat: 100,
          ),
        ]),
      );
      h.proxyReads.single.complete(false);
      await flushEvents();
      expect(h.controller.current.networkWarnings, isEmpty);

      h.emitElectrum(newLiquidKey, isLiquid: true, success: false, runId: 2);
      await flushEvents();
      final warning = h.controller.current.networkWarnings.single;
      expect(warning.reason, ElectrumServerDown.liquid);
    },
  );

  test(
    'late Electrum results stay excluded after same-key admission',
    () async {
      final key = WalletKey(id: 'same', network: BitcoinNetwork.regtest);
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('same', balanceSat: 100),
        ]),
      );
      await flushEvents();
      h.started.add((key: key, runId: 1));
      await flushEvents();

      h.source.publish(snapshot(OverviewCatalogueStatus.revoked, const []));
      await flushEvents();
      h.electrum.add((key: key, runId: 1, isLiquid: false, success: false));
      await flushEvents();
      expect(h.controller.current.networkWarnings, isEmpty);

      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('same', balanceSat: 100),
        ]),
      );
      await flushEvents();
      h.electrum.add((key: key, runId: 1, isLiquid: false, success: false));
      await flushEvents();
      expect(h.controller.current.networkWarnings, isEmpty);

      h.emitElectrum(key, isLiquid: false, success: false, runId: 2);
      await flushEvents();
      expect(
        h.controller.current.networkWarnings.single.reason,
        ElectrumServerDown.bitcoin,
      );
    },
  );

  test('a newer run retires an older pending proxy diagnostic', () async {
    final key = WalletKey(id: 'same', network: BitcoinNetwork.regtest);
    h.manualProxy = true;
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('same', balanceSat: 100),
      ]),
    );
    await flushEvents();

    h.emitElectrum(key, isLiquid: false, success: false, runId: 1);
    await flushEvents();
    expect(h.proxyReads, hasLength(1));
    h.started.add((key: key, runId: 2));
    await flushEvents();
    h.proxyReads.first.complete(false);
    await flushEvents();
    expect(h.controller.current.networkWarnings, isEmpty);

    h.electrum.add((key: key, runId: 2, isLiquid: false, success: false));
    await flushEvents();
    expect(h.proxyReads, hasLength(2));
    h.proxyReads.last.complete(false);
    await flushEvents();
    expect(
      h.controller.current.networkWarnings.single.reason,
      ElectrumServerDown.bitcoin,
    );
  });

  test('a retired proxy result cannot contaminate another chain', () async {
    final bitcoin = WalletKey(id: 'btc', network: BitcoinNetwork.regtest);
    final liquid = WalletKey(id: 'liquid', network: LiquidNetwork.regtest);
    h.manualProxy = true;
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc', balanceSat: 100),
        homeWallet('liquid', network: LiquidNetwork.regtest, balanceSat: 100),
      ]),
    );
    await flushEvents();

    h.emitElectrum(bitcoin, isLiquid: false, success: false, runId: 1);
    await flushEvents();
    expect(h.proxyReads, hasLength(1));
    h.started.add((key: bitcoin, runId: 2));
    await flushEvents();
    h.proxyReads.first.complete(false);
    await flushEvents();
    expect(h.controller.current.networkWarnings, isEmpty);

    h.emitElectrum(liquid, isLiquid: true, success: false, runId: 3);
    await flushEvents();
    expect(h.proxyReads, hasLength(1));
    expect(
      h.controller.current.networkWarnings.single.reason,
      ElectrumServerDown.liquid,
    );
  });

  test('current failures on both chains combine across a proxy wait', () async {
    final bitcoin = WalletKey(id: 'btc', network: BitcoinNetwork.regtest);
    final liquid = WalletKey(id: 'liquid', network: LiquidNetwork.regtest);
    h.manualProxy = true;
    await h.mount();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc', balanceSat: 100),
        homeWallet('liquid', network: LiquidNetwork.regtest, balanceSat: 100),
      ]),
    );
    await flushEvents();

    h.emitElectrum(bitcoin, isLiquid: false, success: false, runId: 1);
    await flushEvents();
    expect(h.proxyReads, hasLength(1));
    h.emitElectrum(liquid, isLiquid: true, success: false, runId: 2);
    await flushEvents();
    h.proxyReads.single.complete(false);
    await flushEvents();
    expect(h.proxyReads, hasLength(2));
    h.proxyReads.last.complete(false);
    await flushEvents();
    expect(
      h.controller.current.networkWarnings.single.reason,
      ElectrumServerDown.both,
    );
  });

  test('swap reachability and notices survive a failed read', () async {
    h.swapServer.isReachable = false;
    await h.mount();
    h.controller.refreshVisible();
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc:regtest', balanceSat: 100),
      ]),
    );
    await flushEvents();
    expect(h.controller.current.swapServerUnreachable, isTrue);

    h.swaps.result = Ok([pendingSwap('swap-1')]);
    h.finished.add(bitcoinKey);
    await flushEvents();
    expect(h.controller.current.ongoingSwaps, hasLength(1));

    h.swaps.result = const Err(OngoingSwapsUnavailableFailure());
    h.finished.add(bitcoinKey);
    await flushEvents();
    expect(h.controller.current.ongoingSwaps, hasLength(1));

    h.swapServer.isReachable = true;
    await h.controller.refresh();
    await flushEvents();
    expect(h.controller.current.swapServerUnreachable, isFalse);
  });

  test(
    'refresh outcome maps to a stale-balance warning and clears it',
    () async {
      await h.mount();
      h.sync.outcome = HomeSyncOutcome.failed;
      await h.controller.refresh();
      await flushEvents();
      expect(
        h.controller.current.loadFailure,
        OverviewLoadFailure.balancesMayBeStale,
      );

      h.sync.outcome = HomeSyncOutcome.busy;
      await h.controller.refresh();
      await flushEvents();
      expect(h.controller.current.loadFailure, isNull);

      h.sync.outcome = HomeSyncOutcome.failed;
      await h.controller.refresh();
      await flushEvents();
      h.sync.outcome = HomeSyncOutcome.completed;
      await h.controller.refresh();
      await flushEvents();
      expect(h.controller.current.loadFailure, isNull);
    },
  );

  test(
    'automatic refresh is waited for; the user pull retries swaps',
    () async {
      await h.mount();
      h.sync.autoComplete = false;
      h.controller.refreshVisible();
      await flushEvents();
      expect(h.sync.triggers, [SyncTrigger.automatic]);
      expect(h.controller.current.isRefreshing, isTrue);

      var waited = false;
      final waiting = h.controller.waitForRefresh().then((_) => waited = true);
      await flushEvents();
      expect(waited, isFalse);

      h.sync.completeNext(HomeSyncOutcome.completed);
      await waiting;
      await flushEvents();
      expect(h.controller.current.isRefreshing, isFalse);

      await h.controller.waitForRefresh();
      expect(waited, isTrue);

      final pull = h.controller.refresh();
      await flushEvents();
      expect(h.sync.triggers.last, SyncTrigger.user);
      verify(() => h.swapActivity.retryOngoingSwaps()).called(1);
      expect(h.controller.current.isRefreshing, isTrue);

      h.sync.completeNext(HomeSyncOutcome.completed);
      await pull;
      await flushEvents();
      expect(h.controller.current.isRefreshing, isFalse);
    },
  );

  test('a later round owns the indicator when rounds overlap', () async {
    await h.mount();
    h.sync.autoComplete = false;
    h.controller.refreshVisible();
    await flushEvents();
    final pull = h.controller.refresh();
    await flushEvents();
    expect(h.sync.pending, 2);

    // The automatic round settles first; the user round still owns the spinner.
    h.sync.completeNext(HomeSyncOutcome.completed);
    await flushEvents();
    expect(h.controller.current.isRefreshing, isTrue);

    h.sync.completeNext(HomeSyncOutcome.completed);
    await pull;
    await flushEvents();
    expect(h.controller.current.isRefreshing, isFalse);
  });

  test('late sync and swap answers after close change nothing', () async {
    await h.mount();
    h.sync.autoComplete = false;
    h.swaps.manual = true;
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('btc:regtest', balanceSat: 100),
      ]),
    );
    await flushEvents();

    h.controller.refreshVisible();
    h.finished.add(bitcoinKey);
    await flushEvents();
    expect(h.sync.pending, 1);

    await h.controller.close();
    expect(h.controller.isClosed, isTrue);

    h.sync.completeNext(HomeSyncOutcome.failed);
    h.swaps.complete(const Ok([]));
    await flushEvents();
    expect(h.controller.isClosed, isTrue);
  });

  test(
    'amount visibility comes from preferences and masks while unknown',
    () async {
      await h.mount();
      expect(h.controller.current.hideAmounts, isNull);

      h.amountPreferences.publish((
        bitcoinUnit: BitcoinUnit.sats,
        hideAmounts: true,
        currencyCode: 'USD',
      ));
      await flushEvents();
      expect(h.controller.current.hideAmounts, isTrue);

      h.amountPreferences.fail(const PreferencesMissingFailure());
      await flushEvents();
      expect(h.controller.current.hideAmounts, isNull);
    },
  );

  test(
    'the Ark scope is the default regtest wallets and their roots',
    () async {
      await h.mount();
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet(
            'btc:regtest',
            isDefault: true,
            masterFingerprint: Fingerprint('aabbccdd'),
          ),
          homeWallet(
            'liquid:regtest',
            network: LiquidNetwork.regtest,
            isDefault: true,
            masterFingerprint: Fingerprint('11223344'),
          ),
        ]),
      );
      await flushEvents();

      final scope = h.controller.current.arkScope;
      expect(scope, contains('btc:regtest'));
      expect(scope, contains('aabbccdd'));
      expect(scope, isNot(contains('liquid:regtest')));
      expect(scope, isNot(contains('11223344')));
    },
  );
}
