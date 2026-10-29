import 'dart:async';

import 'package:bb_mobile/cbf_foreground_service.dart';
import 'package:bb_mobile/cbf_foreground_sync.dart';
import 'package:bb_mobile/cbf_lifecycle.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Facade extends Mock implements WalletTransactionSyncFacade {}

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Settings extends Mock implements SettingsRepository {}

final class _Service implements CbfForegroundService {
  final lost = StreamController<void>.broadcast(sync: true);
  bool active = false;
  bool granted = true;
  int starts = 0;
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
    return active = granted;
  }

  @override
  Future<void> updateProgress({
    required String body,
    required int? percentage,
  }) async {}

  @override
  Future<bool> renew() async {
    if (active) renewals++;
    return active;
  }

  @override
  Future<void> stop() async {
    active = false;
  }

  void timeout() {
    active = false;
    lost.add(null);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await lost.close();
  }
}

final class _Harness {
  final facade = _Facade();
  final metadata = _Metadata();
  final service = _Service();
  final wallets = StreamController<List<WalletMetadataModel>>(sync: true);
  final holds = <bool>[];
  late final CbfForegroundSync foreground;
  late final CbfLifecycle lifecycle;
  void Function()? ownerPoll;
  int reconciles = 0;
  int pauses = 0;
  bool admitted = false;
  Completer<Result<void, WalletTransactionSyncFailure>>? nextPause;

  _Harness() {
    when(() => facade.stopCbfNodes()).thenAnswer((_) async => const Ok(null));
    when(() => facade.pauseCbfNodes()).thenAnswer((_) async {
      pauses++;
      final gate = nextPause;
      nextPause = null;
      if (gate != null) return gate.future;
      return const Ok(null);
    });
    when(() => facade.reconcileCbfWallets(any())).thenAnswer((_) async {
      reconciles++;
      return const Ok(null);
    });
    when(() => facade.setCbfOwnerPoll(any())).thenAnswer((invocation) {
      ownerPoll = invocation.positionalArguments.single as void Function()?;
    });
    when(() => facade.setCbfForegroundActive(any())).thenAnswer((invocation) {
      admitted = invocation.positionalArguments.single as bool;
    });
    when(() => metadata.watchSyncPolicies()).thenAnswer((_) => wallets.stream);
    foreground = CbfForegroundSync(
      service: service,
      labels: () async => (
        title: 'Bull Bitcoin',
        body: 'Syncing wallet',
        progressBody: (percent) => 'Syncing wallet · $percent%',
      ),
      onProtectionChanged: () => lifecycle.protectionChanged(),
    );
    lifecycle = CbfLifecycle(
      platform: TargetPlatform.android,
      routing: BitcoinSyncRouting(
        facade: facade,
        settings: _Settings(),
        tor: () => throw StateError(
          'No route verification expected for an empty registry',
        ),
      ),
      metadata: metadata,
      foregroundSync: foreground,
      onBackgroundProtectionChanged: holds.add,
    );
  }

  Future<void> start() async {
    lifecycle.start(AppLifecycleState.resumed);
    wallets.add([]);
    await until(() => reconciles == 1);
  }

  void recovery() => foreground.observe(
    const BitcoinSyncProgress(
      key: WalletNetworkKey('injected-recovery', 'bitcoin', 'mainnet'),
      phase: BitcoinSyncPhase.checkingBlocks,
      isRecovery: true,
      reachedHeight: 1000,
      targetHeight: 100000,
    ),
  );

  Future<void> close() async {
    await lifecycle.dispose();
    await wallets.close();
  }
}

Future<void> until(bool Function() condition) async {
  for (var index = 0; index < 400 && !condition(); index++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(
    condition(),
    isTrue,
    reason: 'bounded asynchronous lifecycle transition',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'protected hidden, paused and resumed retain the existing native generation',
    () async {
      final harness = _Harness();
      addTearDown(harness.close);
      await harness.start();
      harness.recovery();
      await until(() => harness.foreground.protected);
      final pauses = harness.pauses;
      final reconciles = harness.reconciles;

      harness.lifecycle.onStateChange(AppLifecycleState.inactive);
      harness.lifecycle.onStateChange(AppLifecycleState.hidden);
      harness.lifecycle.onStateChange(AppLifecycleState.paused);
      harness.lifecycle.onStateChange(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(harness.foreground.protected, isTrue);
      expect(harness.pauses, pauses);
      expect(harness.reconciles, reconciles);
      expect(harness.admitted, isTrue);
      expect(harness.holds.last, isTrue);
    },
  );

  test(
    'denial pauses the node in background and resume rebuilds once',
    () async {
      final harness = _Harness()..service.granted = false;
      addTearDown(harness.close);
      await harness.start();
      harness.recovery();
      await until(() => harness.service.starts == 1);
      final pauses = harness.pauses;
      final reconciles = harness.reconciles;

      harness.lifecycle.onStateChange(AppLifecycleState.hidden);
      expect(harness.pauses, pauses + 1);
      expect(harness.admitted, isFalse);
      harness.lifecycle.onStateChange(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(harness.reconciles, reconciles);
      expect(harness.foreground.protected, isFalse);

      harness.lifecycle.onStateChange(AppLifecycleState.resumed);
      await until(() => harness.reconciles == reconciles + 1);
      expect(harness.admitted, isTrue);
    },
  );

  test(
    'timeout while hidden immediately closes admission and pauses without replacement',
    () async {
      final harness = _Harness();
      addTearDown(harness.close);
      await harness.start();
      harness.recovery();
      await until(() => harness.foreground.protected);
      harness.lifecycle.onStateChange(AppLifecycleState.hidden);
      final pauses = harness.pauses;
      final reconciles = harness.reconciles;
      harness.service.timeout();

      expect(harness.admitted, isFalse);
      expect(harness.pauses, pauses + 1);
      expect(harness.holds.last, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(harness.reconciles, reconciles);
      expect(harness.foreground.protected, isFalse);
    },
  );

  test(
    'same-isolate heartbeat supervision exists only during protection',
    () async {
      final harness = _Harness();
      addTearDown(harness.close);
      await harness.start();
      harness.ownerPoll?.call();
      expect(harness.service.renewals, 0);
      harness.recovery();
      await until(() => harness.foreground.protected);
      harness.lifecycle.onStateChange(AppLifecycleState.hidden);
      // No facade poll is called: the same owner's supervised retry/offline timer
      // keeps only platform protection alive, never a BDK node lease.
      await until(() => harness.service.renewals > 0);
      final renewals = harness.service.renewals;
      harness.service.timeout();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      harness.ownerPoll?.call();
      expect(harness.service.renewals, renewals);
      expect(harness.foreground.protected, isFalse);
    },
  );

  test('detached stops even a protected owner and releases Tor hold', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    harness.recovery();
    await until(() => harness.foreground.protected);
    final pauses = harness.pauses;
    harness.lifecycle.onStateChange(AppLifecycleState.detached);
    expect(harness.admitted, isFalse);
    expect(harness.pauses, pauses + 1);
    await until(
      () => !harness.foreground.protected && harness.holds.last == false,
    );
  });

  test('policy error invalidates a refresh waiting on native pause', () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    final gate = Completer<Result<void, WalletTransactionSyncFailure>>();
    harness.nextPause = gate;
    harness.lifecycle.refresh();
    final reconciles = harness.reconciles;
    harness.wallets.addError(const FormatException('metadata unavailable'));
    gate.complete(const Ok(null));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(
      harness.reconciles,
      reconciles,
      reason:
          'an in-flight old policy must not re-open network admission after observation failed',
    );
    expect(harness.admitted, isFalse);
  });
}
