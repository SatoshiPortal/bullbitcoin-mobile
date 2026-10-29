import 'dart:async';

import 'package:bb_mobile/cbf_foreground_service.dart';
import 'package:bb_mobile/cbf_foreground_sync.dart';
import 'package:bb_mobile/cbf_lifecycle.dart';
import 'package:bb_mobile/core/background_tasks/cbf_sync_network_policy.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class _Facade extends Mock implements WalletTransactionSyncFacade {}

final class _Metadata extends Mock implements WalletMetadataDatasource {}

final class _Settings extends Mock implements SettingsRepository {}

final class _WifiOnly implements CbfWifiOnlyPreferenceStore {
  @override
  Future<bool> read() async => true;
  @override
  Future<void> write(bool enabled) async {}
}

final class _Service implements CbfForegroundService {
  final _lost = StreamController<void>.broadcast(sync: true);
  bool _active = false;
  @override
  bool get isActive => _active;
  @override
  Stream<void> get protectionLost => _lost.stream;
  @override
  Future<bool> start({required String title, required String body}) async =>
      _active = true;
  @override
  Future<bool> renew() async => _active;
  @override
  Future<void> stop() async {
    _active = false;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _lost.close();
  }
}

Future<void> _until(bool Function() condition) async {
  for (var index = 0; index < 300 && !condition(); index++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

Future<void> _flush() async {
  for (var count = 0; count < 8; count++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(() => true);
  test(
    'protected hide cannot reopen admission during pending cost validation',
    () async {
      final facade = _Facade();
      final metadata = _Metadata();
      final wallets = StreamController<List<WalletMetadataModel>>.broadcast(
        sync: true,
      );
      var reconciles = 0;
      var reads = 0;
      bool Function()? admission;
      Completer<CbfNetworkSignal?>? heldRead;
      final policy = CbfSyncNetworkPolicy(
        preferences: _WifiOnly(),
        nativeSignals: false,
        readConnectivity: () async => [ConnectivityResult.wifi],
        connectivityChanges: const Stream.empty(),
        readSignal: () async {
          reads++;
          final pending = heldRead;
          if (pending != null) return pending.future;
          return (available: true, metered: false);
        },
      );
      expect(
        await policy.start(),
        isA<Ok<void, WalletTransactionSyncFailure>>(),
      );
      when(() => facade.stopCbfNodes()).thenAnswer((_) async => const Ok(null));
      when(
        () => facade.pauseCbfNodes(),
      ).thenAnswer((_) async => const Ok(null));
      when(() => facade.reconcileCbfWallets(any())).thenAnswer((_) async {
        reconciles++;
        return const Ok(null);
      });
      when(() => facade.setCbfNetworkAdmission(any())).thenAnswer((call) {
        admission = call.positionalArguments.first as bool Function();
      });
      when(
        () => metadata.watchSyncPolicies(),
      ).thenAnswer((_) => wallets.stream);
      final service = _Service();
      CbfLifecycle? lifecycle;
      final sync = CbfForegroundSync(
        service: service,
        labels: () async => (title: 'Bull Bitcoin', body: 'Syncing wallet'),
        onProtectionChanged: () => lifecycle?.protectionChanged(),
      );
      final activeLifecycle = CbfLifecycle(
        routing: BitcoinSyncRouting(
          facade: facade,
          settings: _Settings(),
          tor: () => throw StateError('No fallback'),
        ),
        metadata: metadata,
        networkPolicy: policy,
        foregroundSync: sync,
        platform: TargetPlatform.android,
      );
      lifecycle = activeLifecycle;
      addTearDown(() async {
        await activeLifecycle.dispose();
        await policy.dispose();
        await wallets.close();
      });
      activeLifecycle.start(AppLifecycleState.resumed);
      wallets.add([]);
      await _until(() => reconciles == 1);
      // A live long recovery has already acquired its foreground protection.
      sync.observe(
        const BitcoinSyncProgress(
          key: WalletNetworkKey('public-wallet', 'bitcoin', 'mainnet'),
          phase: BitcoinSyncPhase.checkingBlocks,
          isRecovery: true,
        ),
      );
      await _until(() => sync.protected);
      activeLifecycle.onStateChange(AppLifecycleState.hidden);
      await _flush();
      expect(sync.protected, isTrue);
      final before = reconciles;
      final readsBefore = reads;
      final pending = Completer<CbfNetworkSignal?>();
      heldRead = pending;
      activeLifecycle.onStateChange(AppLifecycleState.resumed);
      await _until(() => reads > readsBefore);
      expect(admission?.call(), isFalse);
      // Lock again while the fresh OS cost is still unknown.
      activeLifecycle.onStateChange(AppLifecycleState.hidden);
      await _flush();
      expect(
        admission?.call(),
        isFalse,
        reason: 'Foreground protection does not prove current network cost',
      );
      expect(
        reconciles,
        before,
        reason:
            'A canceled lifecycle token cannot reopen old unmetered admission',
      );
      pending.complete((available: true, metered: true));
      await _flush();
      expect(policy.current.pauseReason, CbfNetworkPauseReason.mobileData);
      expect(admission?.call(), isFalse);
      expect(reconciles, before);
    },
  );
}
