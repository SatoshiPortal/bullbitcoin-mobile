import 'dart:async';

import 'package:bb_mobile/cbf_foreground_service.dart';
import 'package:bb_mobile/cbf_foreground_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class FakeForegroundService implements CbfForegroundService {
  final lost = StreamController<void>.broadcast(sync: true);
  bool active = false;
  bool grantsStart = true;
  bool grantsRenewal = true;
  bool throwsRenewal = false;
  Completer<bool>? startGate;
  int starts = 0;
  int stops = 0;
  int renewals = 0;

  @override
  bool get isActive => active;

  @override
  Stream<void> get protectionLost => lost.stream;

  @override
  Future<bool> start({
    required String title,
    required String body,
    int? percentage,
  }) async {
    starts++;
    return active = await (startGate?.future ?? Future.value(grantsStart));
  }

  @override
  Future<void> updateProgress({
    required String body,
    required int? percentage,
  }) async {}

  @override
  Future<void> stop() async {
    stops++;
    active = false;
  }

  @override
  Future<bool> renew() async {
    renewals++;
    if (throwsRenewal) throw Exception('renew unavailable');
    return grantsRenewal;
  }

  void lose() {
    active = false;
    lost.add(null);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await lost.close();
  }
}

void main() {
  const key = WalletNetworkKey('one', 'bitcoin', 'mainnet');
  const other = WalletNetworkKey('two', 'bitcoin', 'mainnet');
  late FakeForegroundService service;
  late CbfForegroundSync sync;
  late Duration elapsed;
  late int changes;

  BitcoinSyncProgress progress({
    WalletNetworkKey wallet = key,
    bool recovery = false,
    int reached = 100,
    int target = 101,
    BitcoinSyncPhase phase = BitcoinSyncPhase.checkingBlocks,
    WalletTransactionSyncFailure? failure,
  }) => BitcoinSyncProgress(
    key: wallet,
    phase: phase,
    isRecovery: recovery,
    reachedHeight: reached,
    targetHeight: target,
    failure: failure,
  );

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    elapsed = Duration.zero;
    changes = 0;
    service = FakeForegroundService();
    sync = CbfForegroundSync(
      service: service,
      labels: () async => (
        title: 'Bull Bitcoin',
        body: 'Syncing wallet',
        progressBody: (percent) => 'Syncing wallet · $percent%',
      ),
      onProtectionChanged: () => changes++,
      elapsed: () => elapsed,
    );
  });

  tearDown(() => sync.dispose());

  test(
    'ordinary catch-up stays unprotected; lag 1000 requests protection',
    () async {
      sync.observe(progress(target: 1099));
      await settle();
      expect(service.starts, 0);
      sync.observe(progress(target: 1100));
      await settle();
      expect(service.starts, 1);
      expect(sync.protected, isTrue);
      // Keep the admitted long catch-up protected until its final persisted tip.
      sync.observe(progress(reached: 1099, target: 1100));
      await settle();
      expect(sync.protected, isTrue);
    },
  );

  test(
    'recovery requests protection even while finding peers without heights',
    () async {
      sync.observe(
        const BitcoinSyncProgress(
          key: key,
          phase: BitcoinSyncPhase.findingPeers,
          isRecovery: true,
        ),
      );
      await settle();
      expect(service.starts, 1);
      expect(sync.protected, isTrue);
    },
  );

  test('tip, failure and cancel stop the last protected wallet', () async {
    sync.observe(progress(recovery: true));
    await settle();
    sync.observe(progress(phase: BitcoinSyncPhase.done));
    await settle();
    expect(sync.protected, isFalse);
    sync.observe(progress(recovery: true));
    await settle();
    sync.observe(progress(failure: const CbfTorUnavailableFailure()));
    await settle();
    expect(sync.protected, isFalse);
    sync.observe(progress(recovery: true));
    await settle();
    sync.cancel(key);
    await settle();
    expect(sync.protected, isFalse);
    expect(service.starts, 3);
  });

  test(
    'one completed wallet keeps protection for another recovering wallet',
    () async {
      sync.observe(progress(recovery: true));
      sync.observe(progress(wallet: other, recovery: true));
      await settle();
      sync.observe(progress(phase: BitcoinSyncPhase.done));
      await settle();
      expect(sync.protected, isTrue);
      expect(service.starts, 1);
      sync.cancel(other);
      await settle();
      expect(sync.protected, isFalse);
    },
  );

  test(
    'visible start survives app pause while denied start uses fallback',
    () async {
      sync.observe(progress(recovery: true));
      await settle();
      sync.setVisible(false);
      await settle();
      expect(sync.protected, isTrue);
      expect(service.starts, 1);
      sync.cancel(key);
      await settle();
      sync.setVisible(true);
      service.grantsStart = false;
      sync.observe(progress(recovery: true));
      await settle();
      sync.setVisible(false);
      await settle();
      expect(sync.protected, isFalse);
    },
  );

  test('background demand never launches a new foreground service', () async {
    sync.setVisible(false);
    sync.observe(progress(recovery: true));
    await settle();
    expect(service.starts, 0);
    sync.setVisible(true);
    await settle();
    expect(service.starts, 1);
  });

  test(
    'denial does not repeatedly prompt on progress and retries on resume',
    () async {
      service.grantsStart = false;
      sync.observe(progress(recovery: true));
      await settle();
      sync.observe(progress(recovery: true, reached: 101));
      await settle();
      expect(service.starts, 1);
      sync.setVisible(false);
      service.grantsStart = true;
      sync.setVisible(true);
      await settle();
      expect(service.starts, 2);
      expect(sync.protected, isTrue);
    },
  );

  test(
    'network policy pause stops service and return restarts while visible',
    () async {
      sync.observe(progress(recovery: true));
      await settle();
      sync.setAllowed(false);
      await settle();
      expect(sync.protected, isFalse);
      sync.setAllowed(true);
      await settle();
      expect(sync.protected, isTrue);
      expect(service.starts, 2);
    },
  );

  test(
    'heartbeats only follow explicit owner polls, throttled monotonically',
    () async {
      sync.observe(progress(recovery: true));
      await settle();
      elapsed += const Duration(minutes: 1);
      await settle();
      expect(service.renewals, 0);
      sync.heartbeat();
      await settle();
      expect(service.renewals, 1);
      sync.heartbeat();
      elapsed += const Duration(milliseconds: 999);
      sync.heartbeat();
      await settle();
      expect(service.renewals, 1);
      elapsed += const Duration(milliseconds: 1);
      sync.heartbeat();
      await settle();
      expect(service.renewals, 2);
    },
  );

  for (final throws in [false, true]) {
    test(
      'renewal ${throws ? 'exception' : 'refusal'} falls back without lost event',
      () async {
        sync.observe(progress(recovery: true));
        await settle();
        service.grantsRenewal = false;
        service.throwsRenewal = throws;
        sync.heartbeat();
        await settle();
        expect(sync.protected, isFalse);
        expect(service.active, isFalse);
        expect(changes, greaterThanOrEqualTo(2));
      },
    );
  }

  test(
    'timeout clears protection while backgrounded without restart',
    () async {
      sync.observe(progress(recovery: true));
      await settle();
      sync.setVisible(false);
      service.lose();
      await settle();
      expect(sync.protected, isFalse);
      sync.observe(progress(recovery: true, reached: 101));
      await settle();
      expect(service.starts, 1);
    },
  );

  test(
    'loss during suspended start stops a late success without protection',
    () async {
      final gate = service.startGate = Completer<bool>();
      sync.observe(progress(recovery: true));
      await settle();
      service.lose();
      gate.complete(true);
      await settle();
      expect(sync.protected, isFalse);
      expect(service.active, isFalse);
      expect(service.starts, 1);
    },
  );

  test(
    'removed demand during asynchronous labels never starts service',
    () async {
      await sync.dispose();
      final text = Completer<CbfSyncNotificationLabels>();
      sync = CbfForegroundSync(
        service: service = FakeForegroundService(),
        labels: () => text.future,
        onProtectionChanged: () => changes++,
        elapsed: () => elapsed,
      );
      sync.observe(progress(recovery: true));
      sync.cancel(key);
      text.complete((
        title: 'Bull Bitcoin',
        body: 'Syncing wallet',
        progressBody: (percent) => 'Syncing wallet · $percent%',
      ));
      await settle();
      expect(service.starts, 0);
    },
  );
}
