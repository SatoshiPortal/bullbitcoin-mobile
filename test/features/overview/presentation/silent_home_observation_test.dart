import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/silent.dart';
import 'package:sync/sync.dart' show WalletKey;

import '../support/overview_home_harness.dart';

class _Home {
  final source = FakeOverviewSource();
  final sync = FakeHomeSync();
  final preferences = FakeAmountDisplayPreferences();
  final silent = _Silent();
  final started = StreamController<HomeSyncStart>.broadcast();
  final finished = StreamController<WalletKey>.broadcast();
  final electrum = StreamController<HomeElectrumOutcome>.broadcast();
  late final controller = OverviewHomeController(
    catalogue: source,
    sync: sync,
    amountDisplay: OverviewAmountDisplay(preferences),
    ongoingSwaps: FakeOngoingSwaps(),
    swapServerCheck: FakeSwapServerCheck(),
    readBackupWarning: () async => false,
    readPhysicalBackup: (_) async => true,
    proxyNeedsAttention: () async => false,
    silentHome: SilentHomeObservation(silent),
    syncStarted: started.stream,
    syncFinished: finished.stream,
    electrumResults: electrum.stream,
  );

  Future<void> close() async {
    await controller.close();
    await source.close();
    await sync.close();
    await preferences.close();
    await started.close();
    await finished.close();
    await electrum.close();
    await silent.updates.close();
  }
}

class _Silent extends Fake implements Silent {
  Result<bool, SilentFailure> gate = const Ok(true);
  Result<bool, SilentFailure> setup = const Ok(true);
  Result<SilentWallet?, SilentFailure> answer = const Ok(null);
  final pending = <Completer<Result<SilentWallet?, SilentFailure>>>[];
  bool hold = false;
  bool scanning = false;
  int gates = 0;
  int setups = 0;
  int reads = 0;
  bool cancelled = false;
  late final updates =
      StreamController<Result<SilentUpdate, SilentFailure>>.broadcast(
        onCancel: () => cancelled = true,
      );

  @override
  Future<Result<bool, SilentFailure>> isFeatureEnabled() async {
    gates++;
    return gate;
  }

  @override
  Future<Result<bool, SilentFailure>> isSetUp() async {
    setups++;
    return setup;
  }

  @override
  bool get isScanning => scanning;

  @override
  Future<Result<SilentWallet?, SilentFailure>> refresh() {
    reads++;
    if (!hold) return Future.value(answer);
    final result = Completer<Result<SilentWallet?, SilentFailure>>();
    pending.add(result);
    return result.future;
  }

  @override
  Stream<Result<SilentUpdate, SilentFailure>> watchUpdates() => updates.stream;
}

void main() {
  test('Home accepts only revalidated notification amount and preserves it during scan', () async {
    final h = _Home();
    addTearDown(h.close);
    h.silent.answer = Ok(silentWallet(0, network: BitcoinNetwork.mainnet));
    expect(h.controller.isClosed, isFalse);
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('wallet', network: BitcoinNetwork.mainnet, balanceSat: 100),
      ]),
    );
    await flushEvents();
    expect(h.controller.current.totalSat, 100);
    h.silent.answer = Ok(silentWallet(1234, network: BitcoinNetwork.mainnet));
    final reads = h.silent.reads;
    h.silent.updates.add(Ok(SilentBalanceChanged(Sats.fromInt(9876))));
    await flushEvents();
    expect(h.silent.reads, reads + 1);
    expect(h.controller.current.silent.balanceSat, 1234);
    expect(h.controller.current.totalSat, 1334);
    h.silent.scanning = true;
    h.silent.updates.add(const Ok(SilentSetupChanged()));
    await flushEvents();
    expect(h.silent.reads, reads + 1);
    expect(h.controller.current.silent.configured, isTrue);
    expect(h.controller.current.silent.loading, isFalse);
    expect(h.controller.current.totalSat, 1334);
  });

  test(
    'Home ignores untagged balance notifications while gate is disabled',
    () async {
      final h = _Home();
      addTearDown(h.close);
      h.silent.gate = const Ok(false);
      h.silent.answer = Ok(silentWallet(5000, network: BitcoinNetwork.mainnet));
      expect(h.controller.isClosed, isFalse);
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet(
            'wallet',
            network: BitcoinNetwork.mainnet,
            balanceSat: 100,
          ),
        ]),
      );
      await flushEvents();
      h.silent.updates.add(Ok(SilentBalanceChanged(Sats.fromInt(5000))));
      await flushEvents();
      expect(h.silent.reads, 0);
      expect(h.controller.current.silent.balanceSat, 0);
      expect(h.controller.current.showSilentCard, isFalse);
      expect(h.controller.current.totalSat, 100);
    },
  );

  test('Home observes updates before admission without reading or publishing money', () async {
    final h = _Home();
    addTearDown(h.close);
    h.silent.answer = Ok(silentWallet(9000, network: BitcoinNetwork.mainnet));
    expect(h.controller.isClosed, isFalse);
    h.silent.updates.add(Ok(SilentBalanceChanged(Sats.fromInt(9876))));
    await flushEvents();
    expect(h.silent.reads, 0);
    expect(h.controller.current.showSilentCard, isFalse);
    expect(h.controller.current.totalSat, 0);

    final ready = snapshot(OverviewCatalogueStatus.ready, [
      homeWallet('wallet', network: BitcoinNetwork.mainnet, balanceSat: 100),
    ]);
    h.source.publish(ready);
    await flushEvents();
    expect(h.silent.reads, 1);
    expect(h.controller.current.totalSat, 9100);
    h.source.publish(ready);
    await flushEvents();
    expect(h.silent.reads, 1);
    expect(h.controller.current.totalSat, 9100);
  });

  for (final oldNetwork in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
    for (final scanning in [false, true]) {
      test(
        'Home retires $oldNetwork and notifications during replacement scanning=$scanning',
        () async {
          final h = _Home();
          addTearDown(h.close);
          h.silent.answer = Ok(silentWallet(9000, network: oldNetwork));
          expect(h.controller.isClosed, isFalse);
          h.source.publish(
            snapshot(OverviewCatalogueStatus.ready, [
              homeWallet('old', network: oldNetwork, balanceSat: 100),
            ]),
          );
          await flushEvents();
          expect(h.controller.current.totalSat, 9100);

          h.silent.hold = true;
          h.silent.updates.add(Ok(SilentBalanceChanged(Sats.fromInt(9876))));
          await flushEvents();
          expect(h.silent.pending, hasLength(1));
          h.source.publish(snapshot(OverviewCatalogueStatus.replacing, []));
          await flushEvents();
          expect(h.controller.current.showSilentCard, isFalse);
          expect(h.controller.current.totalSat, 0);
          final reads = h.silent.reads;
          h.silent.updates.add(Ok(SilentBalanceChanged(Sats.fromInt(9876))));
          await flushEvents();
          expect(h.silent.reads, reads);
          h.silent.pending.single.complete(
            Ok(silentWallet(9000, network: oldNetwork)),
          );
          await flushEvents();
          expect(h.controller.current.showSilentCard, isFalse);
          expect(h.controller.current.totalSat, 0);

          h.silent.hold = false;
          h.silent.scanning = scanning;
          final target = oldNetwork == BitcoinNetwork.mainnet
              ? BitcoinNetwork.testnet
              : BitcoinNetwork.mainnet;
          final published = <OverviewHomeState>[];
          void record() => published.add(h.controller.current);
          h.controller.addListener(record);
          h.source.publish(
            snapshot(OverviewCatalogueStatus.ready, [
              homeWallet('new', network: target, balanceSat: 100),
            ]),
          );
          await flushEvents();
          expect(h.controller.current.showSilentCard, isFalse);
          expect(h.controller.current.totalSat, 100);
          expect(published, isNotEmpty);
          expect(
            published.every((s) => !s.showSilentCard && s.totalSat == 100),
            isTrue,
          );
          h.controller.removeListener(record);
        },
      );
    }
  }

  late _Silent silent;
  late SilentHomeObservation home;
  late List<SilentHomeUpdate> published;

  setUp(() {
    silent = _Silent();
    home = SilentHomeObservation(silent);
    published = [];
    home.catalogPublished({NetworkEnv.mainnet});
  });
  tearDown(() async {
    await home.close();
    await silent.updates.close();
  });

  test(
    'loaded snapshot publishes unified rather than confirmed amount',
    () async {
      silent.answer = Ok(
        SilentWallet(
          network: BitcoinNetwork.mainnet,
          spAddress: 'sp1qexample',
          balance: SilentBalance(
            confirmedSat: Sats.fromInt(1),
            totalUnifiedSat: Sats.fromInt(5000),
          ),
          isScanning: false,
        ),
      );
      await home.refresh(published.add);
      expect(published.first.loading, isTrue);
      expect(published.last, (
        visible: true,
        configured: true,
        balanceSat: 5000,
        loading: false,
      ));
      expect(silent.reads, 1);
    },
  );

  for (final gateOn in [false, true]) {
    test('gate=$gateOn with setup false settles without reading', () async {
      silent.gate = Ok(gateOn);
      silent.setup = const Ok(false);
      await home.refresh(published.add);
      expect(published.any((u) => u.configured == false), isTrue);
      expect(published.last.visible, isFalse);
      expect(published.last.balanceSat, 0);
      expect(published.last.loading, isFalse);
      expect(silent.reads, 0);
    });
  }

  test('disabled gate retains setup fact but cannot admit a wallet', () async {
    silent.gate = const Ok(false);
    await home.refresh(published.add);
    expect(published.any((u) => u.configured == true), isTrue);
    expect(published.last.visible, isFalse);
    expect(published.last.balanceSat, 0);
    expect(published.last.loading, isFalse);
    expect(silent.reads, 0);
  });

  test('failed setup settles without throwing or reading', () async {
    silent.setup = const Err(SilentUnexpected('setup failure'));
    await expectLater(home.refresh(published.add), completes);
    expect(published.last.visible, isFalse);
    expect(published.last.balanceSat, 0);
    expect(published.last.loading, isFalse);
    expect(silent.reads, 0);
  });

  test('feature gate logs only a fixed warning', () async {
    final directory = await Directory.systemTemp.createTemp('silent-gate-log-');
    await initializeLogging(directory: directory);
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    silent.gate = const Err(SilentUnexpected('foreign-gate-sentinel'));
    await home.refresh(published.add);
    final lines = await log.readLogs();
    expect(
      lines.join('\n'),
      contains('SP feature gate refresh failed category=feature_gate'),
    );
    expect(lines.join('\n'), isNot(contains('foreign-gate-sentinel')));
    expect(silent.setups, 0);
    expect(silent.reads, 0);
  });

  test(
    'scanning skips snapshot and preserves previous balance patch',
    () async {
      silent.answer = Ok(silentWallet(3000, network: BitcoinNetwork.mainnet));
      await home.refresh(published.add);
      expect(published.last.balanceSat, 3000);
      silent.scanning = true;
      await home.refresh(published.add);
      expect(silent.reads, 1);
      expect(published.last.balanceSat, isNull);
      expect(published.last.visible, isNull);
      expect(published.last.loading, isFalse);
    },
  );

  test('a newer snapshot wins over an older in-flight snapshot', () async {
    silent.hold = true;
    final old = home.refresh(published.add);
    await flushEvents();
    final newer = home.refresh(published.add);
    await flushEvents();
    expect(silent.pending, hasLength(2));
    silent.pending[1].complete(
      Ok(silentWallet(2000, network: BitcoinNetwork.mainnet)),
    );
    await newer;
    final before = published.length;
    silent.pending[0].complete(
      Ok(silentWallet(1000, network: BitcoinNetwork.mainnet)),
    );
    await old;
    expect(published.length, before);
    expect(published.last.balanceSat, 2000);
  });

  test(
    'an untagged event cannot publish its amount or revive an old read',
    () async {
      home.observe(() => unawaited(home.refresh(published.add)));
      silent.hold = true;
      final old = home.refresh(published.add);
      await flushEvents();
      silent.updates.add(Ok(SilentBalanceChanged(Sats.fromInt(9876))));
      await flushEvents();
      expect(silent.pending, hasLength(2));
      silent.pending[1].complete(
        Ok(silentWallet(0, network: BitcoinNetwork.mainnet)),
      );
      await flushEvents();
      final count = published.length;
      silent.pending[0].complete(
        Ok(silentWallet(9000, network: BitcoinNetwork.mainnet)),
      );
      await old;
      expect(published.length, count);
      expect(published.last.balanceSat, 0);
      expect(published.any((u) => u.balanceSat == 9876), isFalse);
      expect(published.any((u) => u.balanceSat == 9000), isFalse);
    },
  );

  for (final oldNetwork in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
    test(
      'replacing retires pending $oldNetwork read before new environment',
      () async {
        home.catalogPublished({oldNetwork.env});
        silent.hold = true;
        final old = home.refresh(published.add);
        await flushEvents();
        home.catalogReplacing();
        final count = published.length;
        await home.refresh(published.add);
        expect(silent.reads, 1);
        final next = oldNetwork == BitcoinNetwork.mainnet
            ? NetworkEnv.testnet
            : NetworkEnv.mainnet;
        home.catalogPublished({next});
        silent.pending.single.complete(
          Ok(silentWallet(9000, network: oldNetwork)),
        );
        await old;
        expect(published.length, count);
        silent.hold = false;
        silent.answer = Ok(silentWallet(9000, network: oldNetwork));
        await home.refresh(published.add);
        expect(published.last.visible, isFalse);
        expect(published.last.balanceSat, 0);
        expect(published.last.loading, isFalse);
      },
    );
  }

  test('balance and setup notifications invalidate and never publish their amounts', () async {
    silent.answer = Ok(silentWallet(1234, network: BitcoinNetwork.mainnet));
    home.observe(() => unawaited(home.refresh(published.add)));
    silent.updates.add(Ok(SilentBalanceChanged(Sats.fromInt(9876))));
    await flushEvents();
    expect(silent.gates, 1);
    expect(silent.setups, 1);
    expect(silent.reads, 1);
    expect(published.last.balanceSat, 1234);
    silent.updates.add(const Ok(SilentSetupChanged()));
    await flushEvents();
    expect(silent.gates, 2);
    expect(silent.setups, 2);
    expect(silent.reads, 2);
    expect(published.last.balanceSat, 1234);
  });

  test('close cancels updates and retires pending read', () async {
    home.observe(() => unawaited(home.refresh(published.add)));
    silent.hold = true;
    final read = home.refresh(published.add);
    await flushEvents();
    await home.close();
    expect(silent.cancelled, isTrue);
    final count = published.length;
    silent.pending.single.complete(
      Ok(silentWallet(9000, network: BitcoinNetwork.mainnet)),
    );
    await read;
    expect(published.length, count);
    await home.refresh(published.add);
    expect(silent.reads, 1);
  });
}
