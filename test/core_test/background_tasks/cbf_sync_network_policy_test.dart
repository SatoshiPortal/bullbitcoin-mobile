import 'dart:async';

import 'package:bb_mobile/core/background_tasks/cbf_sync_network_policy.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class _Preferences implements CbfWifiOnlyPreferenceStore {
  bool value;
  bool denyRead = false;
  bool denyWrite = false;
  final writes = <bool>[];
  Completer<void>? writeGate;

  _Preferences([this.value = false]);

  @override
  Future<bool> read() async {
    if (denyRead) throw const FormatException('storage unavailable');
    return value;
  }

  @override
  Future<void> write(bool enabled) async {
    writes.add(enabled);
    await writeGate?.future;
    if (denyWrite) throw const FormatException('storage unavailable');
    value = enabled;
  }
}

Future<CbfSyncNetworkPolicy> _policy({
  _Preferences? preferences,
  CbfNetworkSignal? signal = (available: true, metered: true),
  Stream<CbfNetworkSignal> changes = const Stream.empty(),
  List<ConnectivityResult> transports = const [ConnectivityResult.wifi],
  Stream<List<ConnectivityResult>> transportChanges = const Stream.empty(),
  bool nativeSignals = false,
}) async {
  final policy = CbfSyncNetworkPolicy(
    preferences: preferences ?? _Preferences(),
    readConnectivity: () async => transports,
    connectivityChanges: transportChanges,
    readSignal: () async => signal,
    signalChanges: changes,
    nativeSignals: nativeSignals,
  );
  addTearDown(policy.dispose);
  expect(await policy.start(), isA<Ok<void, WalletTransactionSyncFailure>>());
  return policy;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default permits mobile data without writing a preference', () async {
    final preferences = _Preferences();
    final policy = await _policy(preferences: preferences);
    expect(policy.current.initialized, isTrue);
    expect(policy.current.wifiOnly, isFalse);
    expect(policy.current.metered, isTrue);
    expect(policy.current.canSync, isTrue);
    expect(policy.current.pauseReason, isNull);
    expect(preferences.writes, isEmpty);
  });

  test('metered Wi-Fi pauses only after Wi-Fi-only is persisted', () async {
    final preferences = _Preferences();
    final policy = await _policy(
      preferences: preferences,
      transports: const [ConnectivityResult.wifi],
      signal: (available: true, metered: true),
    );
    expect(
      await policy.setWifiOnly(true),
      isA<Ok<void, WalletTransactionSyncFailure>>(),
    );
    expect(preferences.value, isTrue);
    expect(policy.current.canSync, isFalse);
    expect(policy.current.pauseReason, CbfNetworkPauseReason.mobileData);
  });

  test(
    'unmetered mobile uses platform cost instead of its interface',
    () async {
      final policy = await _policy(
        preferences: _Preferences(true),
        transports: const [ConnectivityResult.mobile],
        signal: (available: true, metered: false),
      );
      expect(policy.current.canSync, isTrue);
    },
  );

  test(
    'session consent resumes without changing the persistent setting',
    () async {
      final preferences = _Preferences(true);
      final policy = await _policy(preferences: preferences);
      expect(policy.current.canSync, isFalse);
      policy.continueOnMobileData();
      expect(policy.current.canSync, isTrue);
      expect(policy.current.mobileDataOverride, isTrue);
      expect(preferences.value, isTrue);
      expect(preferences.writes, isEmpty);
      await policy.dispose();
      final replacement = await _policy(preferences: preferences);
      expect(replacement.current.wifiOnly, isTrue);
      expect(replacement.current.mobileDataOverride, isFalse);
      expect(replacement.current.pauseReason, CbfNetworkPauseReason.mobileData);
    },
  );

  test(
    'offline takes precedence over consent and returns immediately',
    () async {
      final changes = StreamController<CbfNetworkSignal>.broadcast(sync: true);
      addTearDown(changes.close);
      final policy = await _policy(
        preferences: _Preferences(true),
        changes: changes.stream,
      );
      policy.continueOnMobileData();
      changes.add((available: false, metered: null));
      expect(policy.current.canSync, isFalse);
      expect(policy.current.pauseReason, CbfNetworkPauseReason.offline);
      changes.add((available: true, metered: true));
      expect(policy.current.canSync, isTrue);
      expect(policy.current.wifiOnly, isTrue);
    },
  );

  test(
    'flapping publishes distinct admission states without busy polling',
    () async {
      final changes = StreamController<CbfNetworkSignal>.broadcast(sync: true);
      addTearDown(changes.close);
      final policy = await _policy(
        preferences: _Preferences(true),
        changes: changes.stream,
        signal: (available: true, metered: false),
      );
      final observed = <CbfNetworkPolicyState>[];
      final subscription = policy.watch().listen(observed.add);
      addTearDown(subscription.cancel);
      await _flush();
      observed.clear();
      changes.add((available: false, metered: null));
      changes.add((available: false, metered: null));
      changes.add((available: true, metered: true));
      changes.add((available: true, metered: true));
      changes.add((available: true, metered: false));
      await _flush();
      expect(observed.map((state) => state.pauseReason), [
        CbfNetworkPauseReason.offline,
        CbfNetworkPauseReason.mobileData,
        null,
      ]);
    },
  );

  test('denied preference write preserves the active policy', () async {
    final preferences = _Preferences()..denyWrite = true;
    final policy = await _policy(preferences: preferences);
    final before = policy.current;
    expect(
      await policy.setWifiOnly(true),
      isA<Err<void, WalletTransactionSyncFailure>>(),
    );
    expect(policy.current, before);
    expect(preferences.value, isFalse);
    expect(policy.current.canSync, isTrue);
  });

  test(
    'unread saved preference never admits sync with a fabricated default',
    () async {
      final preferences = _Preferences(true)..denyRead = true;
      final policy = CbfSyncNetworkPolicy(
        preferences: preferences,
        nativeSignals: false,
        readConnectivity: () async => [ConnectivityResult.wifi],
        connectivityChanges: const Stream.empty(),
        readSignal: () async => (available: true, metered: true),
      );
      addTearDown(policy.dispose);
      expect(
        await policy.start(),
        isA<Err<void, WalletTransactionSyncFailure>>(),
      );
      expect(policy.current.initialized, isFalse);
      expect(policy.current.canSync, isFalse);
      preferences.denyRead = false;
      expect(
        await policy.reloadPreference(),
        isA<Ok<void, WalletTransactionSyncFailure>>(),
      );
      expect(policy.current.wifiOnly, isTrue);
      expect(policy.current.canSync, isFalse);
    },
  );

  test('missing mobile native adapter keeps Wi-Fi cost unknown', () async {
    final policy = await _policy(
      preferences: _Preferences(true),
      nativeSignals: true,
      signal: null,
      transports: const [ConnectivityResult.wifi],
    );
    expect(policy.current.metered, isNull);
    expect(policy.current.pauseReason, CbfNetworkPauseReason.mobileData);
    policy.continueOnMobileData();
    expect(policy.current.canSync, isTrue);
  });

  test(
    'new platform callback wins over an older pending native read',
    () async {
      final pending = Completer<CbfNetworkSignal?>();
      final changes = StreamController<CbfNetworkSignal>.broadcast(sync: true);
      addTearDown(changes.close);
      final policy = CbfSyncNetworkPolicy(
        preferences: _Preferences(),
        nativeSignals: false,
        readConnectivity: () async => [ConnectivityResult.wifi],
        connectivityChanges: const Stream.empty(),
        readSignal: () => pending.future,
        signalChanges: changes.stream,
      );
      addTearDown(policy.dispose);
      final started = policy.start();
      await _flush();
      changes.add((available: true, metered: false));
      pending.complete((available: false, metered: true));
      expect(await started, isA<Ok<void, WalletTransactionSyncFailure>>());
      expect(policy.current.available, isTrue);
      expect(policy.current.metered, isFalse);
    },
  );

  test(
    'plugin connectivity changes pause offline and resume without polling',
    () async {
      var transports = <ConnectivityResult>[ConnectivityResult.wifi];
      var reads = 0;
      final changes = StreamController<List<ConnectivityResult>>.broadcast(
        sync: true,
      );
      addTearDown(changes.close);
      final policy = CbfSyncNetworkPolicy(
        preferences: _Preferences(),
        nativeSignals: false,
        readConnectivity: () async {
          reads++;
          return transports;
        },
        connectivityChanges: changes.stream,
        readSignal: () async => null,
      );
      addTearDown(policy.dispose);
      expect(
        await policy.start(),
        isA<Ok<void, WalletTransactionSyncFailure>>(),
      );
      expect(policy.current.canSync, isTrue);
      transports = [ConnectivityResult.none];
      changes.add(transports);
      await _flush();
      expect(policy.current.pauseReason, CbfNetworkPauseReason.offline);
      final offlineReads = reads;
      await _flush();
      expect(reads, offlineReads);
      transports = [ConnectivityResult.mobile];
      changes.add(transports);
      await _flush();
      expect(policy.current.canSync, isTrue);
    },
  );

  test(
    'serialized preference writes finish with the last requested value',
    () async {
      final preferences = _Preferences()..writeGate = Completer<void>();
      final policy = await _policy(preferences: preferences);
      final enable = policy.setWifiOnly(true);
      final disable = policy.setWifiOnly(false);
      await _flush();
      expect(preferences.writes, [true]);
      preferences.writeGate?.complete();
      expect(await enable, isA<Ok<void, WalletTransactionSyncFailure>>());
      expect(await disable, isA<Ok<void, WalletTransactionSyncFailure>>());
      expect(preferences.writes, [true, false]);
      expect(preferences.value, isFalse);
      expect(policy.current.wifiOnly, isFalse);
    },
  );
}
