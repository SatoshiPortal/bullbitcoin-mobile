import 'dart:async';

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

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 300 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

Future<void> _flush() async {
  for (var count = 0; count < 5; count++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(() => true);
  for (final nowMetered in [true, false]) {
    test(
      'resume waits for fresh cost after background event suppression (metered=$nowMetered)',
      () async {
        final facade = _Facade();
        final metadata = _Metadata();
        final wallets = StreamController<List<WalletMetadataModel>>.broadcast(
          sync: true,
        );
        var reconciles = 0;
        var pauses = 0;
        var signalReads = 0;
        bool Function()? admission;
        Completer<CbfNetworkSignal?>? heldRead;
        final policy = CbfSyncNetworkPolicy(
          preferences: _WifiOnly(),
          nativeSignals: false,
          readConnectivity: () async => [ConnectivityResult.wifi],
          connectivityChanges: const Stream.empty(),
          readSignal: () async {
            signalReads++;
            final pending = heldRead;
            if (pending != null) return pending.future;
            return (available: true, metered: false);
          },
        );
        expect(
          await policy.start(),
          isA<Ok<void, WalletTransactionSyncFailure>>(),
        );
        expect(policy.current.canSync, isTrue);
        when(
          () => facade.stopCbfNodes(),
        ).thenAnswer((_) async => const Ok(null));
        when(() => facade.pauseCbfNodes()).thenAnswer((_) async {
          pauses++;
          return const Ok(null);
        });
        when(() => facade.reconcileCbfWallets(any())).thenAnswer((_) async {
          reconciles++;
          return const Ok(null);
        });
        when(() => facade.setCbfNetworkAdmission(any())).thenAnswer((
          invocation,
        ) {
          admission = invocation.positionalArguments.first as bool Function();
        });
        when(
          () => metadata.watchSyncPolicies(),
        ).thenAnswer((_) => wallets.stream);
        final lifecycle = CbfLifecycle(
          routing: BitcoinSyncRouting(
            facade: facade,
            settings: _Settings(),
            tor: () => throw StateError('No Tor or Electrum fallback'),
          ),
          metadata: metadata,
          networkPolicy: policy,
          platform: TargetPlatform.android,
        );
        addTearDown(() async {
          await lifecycle.dispose();
          await policy.dispose();
          await wallets.close();
        });
        lifecycle.start(AppLifecycleState.resumed);
        wallets.add([]);
        await _until(() => reconciles == 1);
        lifecycle.onStateChange(AppLifecycleState.paused);
        await _until(() => pauses >= 2);
        await _flush();
        final before = reconciles;
        final readsBefore = signalReads;
        // No connectivity callback arrives while the app is backgrounded.
        // The formerly unmetered Wi-Fi can now be a costly hotspot/cellular path.
        final pending = Completer<CbfNetworkSignal?>();
        heldRead = pending;
        lifecycle.onStateChange(AppLifecycleState.resumed);
        await _until(() => signalReads > readsBefore);
        await _flush();
        expect(
          admission?.call(),
          isFalse,
          reason: 'Stale pre-pause cost must not admit direct sync requests',
        );
        expect(
          reconciles,
          before,
          reason: 'Node reconstruction must wait for current platform cost',
        );
        pending.complete((available: true, metered: nowMetered));
        await _flush();
        if (nowMetered) {
          expect(policy.current.pauseReason, CbfNetworkPauseReason.mobileData);
          expect(admission?.call(), isFalse);
          expect(reconciles, before);
        } else {
          await _until(() => reconciles == before + 1);
          expect(admission?.call(), isTrue);
        }
      },
    );
  }
}
