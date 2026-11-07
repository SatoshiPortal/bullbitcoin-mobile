import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show TransactionSyncBusyFailure;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transaction_sync/transaction_sync.dart' show SyncReason;
import 'dart:io';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'dart:async';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockCheckWalletSyncingUsecase extends Mock
    implements CheckWalletSyncingUsecase {}

class _MockWatchWalletSyncEventsUsecase extends Mock
    implements WatchWalletSyncEventsUsecase {}

class _MockSyncWalletsUsecase extends Mock implements SyncWalletsUsecase {}

class _MockGetUnconfirmedIncomingBalanceUsecase extends Mock
    implements GetUnconfirmedIncomingBalanceUsecase {}

class _MockDeleteWalletUsecase extends Mock implements DeleteWalletUsecase {}

class _MockCheckBackupNeededUsecase extends Mock
    implements CheckBackupNeededUsecase {}

class _MockExternalTorStatusUsecase extends Mock
    implements GetExternalTorProxyStatusUsecase {}

class _MockCheckSpWalletSetupForWalletUsecase extends Mock
    implements CheckSpWalletSetupForWalletUsecase {}

class _MockCheckSpScanningForWalletUsecase extends Mock
    implements CheckSpScanningForWalletUsecase {}

class _MockRefreshSpWalletForWalletUsecase extends Mock
    implements RefreshSpWalletForWalletUsecase {}

class _MockWatchSpWalletUsecase extends Mock implements WatchSpWalletUsecase {}

class _MockCheckSpFeatureGateForWalletUsecase extends Mock
    implements CheckSpFeatureGateForWalletUsecase {}

WalletBloc createBloc(GetExternalTorProxyStatusUsecase externalStatus) {
  return WalletBloc(
    getWalletsUsecase: _MockGetWalletsUsecase(),
    checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: _stubbedSync(),
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
    getExternalTorProxyStatusUsecase: externalStatus,
    checkSpWalletSetupForWalletUsecase:
        _MockCheckSpWalletSetupForWalletUsecase(),
    checkSpScanningForWalletUsecase: _MockCheckSpScanningForWalletUsecase(),
    refreshSpWalletForWalletUsecase: _MockRefreshSpWalletForWalletUsecase(),
    watchSpWalletUsecase: _MockWatchSpWalletUsecase(),
    checkSpFeatureGateForWalletUsecase:
        _MockCheckSpFeatureGateForWalletUsecase(),
  );
}

class _MockSyncWalletUsecase extends Mock implements SyncWalletUsecase {}

class _ViewWalletBloc extends Mock implements WalletBloc {}

void main() {
  registerFallbackValue(SyncReason.auto);
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final trigger in [SyncTrigger.automatic, SyncTrigger.user]) {
    testWidgets('$trigger busy does not render a generic failure card', (
      tester,
    ) async {
      late WalletState settled;
      await tester.runAsync(() async {
        final dir = Directory.systemTemp.createTempSync('review-fix2-busy-');
        log = Logger.replace(directory: dir);
        final getWallets = _MockGetWalletsUsecase();
        when(
          () => getWallets.execute(),
        ).thenAnswer((_) async => Ok([_syncedWallet]));
        when(
          () => getWallets.execute(onlyBitcoin: true),
        ).thenAnswer((_) async => Ok([_syncedWallet]));
        when(
          () => getWallets.execute(onlyLiquid: true),
        ).thenAnswer((_) async => const Ok(<Wallet>[]));
        final single = _MockSyncWalletUsecase();
        when(
          () => single.execute(
            _syncedWallet,
            discover: false,
            reason: any(named: 'reason'),
          ),
        ).thenThrow(
          const WalletSnapshotException(TransactionSyncBusyFailure()),
        );
        final coordinator = SyncCoordinator(
          getWalletsUsecase: getWallets,
          syncWalletUsecase: single,
        );
        final bloc = WalletBloc(
          getWalletsUsecase: getWallets,
          checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
          watchWalletSyncEventsUsecase: _stubbedWatchers(),
          syncWalletsUsecase: SyncWalletsUsecase(coordinator),
          getUnconfirmedIncomingBalanceUsecase:
              _MockGetUnconfirmedIncomingBalanceUsecase(),
          deleteWalletUsecase: _MockDeleteWalletUsecase(),
          checkSpWalletSetupForWalletUsecase: _stubbedSpSetup(),
          checkSpScanningForWalletUsecase: _stubbedSpScanning(),
          refreshSpWalletForWalletUsecase: _stubbedSpRefresh(),
          watchSpWalletUsecase: _stubbedSpWatch(),
          checkSpFeatureGateForWalletUsecase: _stubbedSpGate(),
          checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
          getExternalTorProxyStatusUsecase: _MockExternalTorStatusUsecase(),
        );

        try {
          bloc.add(WalletRefreshed(trigger: trigger));
          await pumpEventQueue();
          settled = bloc.state;
          expect(settled.isRefreshing, isFalse);
          expect(settled.wallets, [_syncedWallet]);
        } finally {
          await bloc.close();
          coordinator.dispose();
          await log.flush();
          dir.deleteSync(recursive: true);
        }
      });
      final viewBloc = _ViewWalletBloc();
      when(() => viewBloc.state).thenReturn(settled);
      when(
        () => viewBloc.stream,
      ).thenAnswer((_) => const Stream<WalletState>.empty());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<WalletBloc>.value(
              value: viewBloc,
              child: const HomeWarnings(),
            ),
          ),
        ),
      );
      expect(find.textContaining('may be out of date'), findsNothing);
    });
  }

  test('spinner waiter does not request another foreground sync', () async {
    final sync = _MockSyncWalletsUsecase();
    final gate = Completer<Result<void, WalletFailure>>();
    when(
      () => sync.execute(trigger: SyncTrigger.automatic),
    ).thenAnswer((_) => gate.future);
    final bloc = _blocWithFailingLoad(const WalletStorageFailure(), sync: sync);
    addTearDown(bloc.close);
    await bloc.waitForRefresh();
    verifyNever(() => sync.execute());
    bloc.add(const WalletRefreshed());
    await pumpEventQueue();
    expect(bloc.state.isRefreshing, isTrue);
    var settled = false;
    final spinner = bloc.waitForRefresh().then((_) => settled = true);
    await pumpEventQueue();
    expect(settled, isFalse);
    gate.complete(const Err(WalletSyncFailure()));
    await spinner;
    expect(bloc.state.isRefreshing, isFalse);
    verify(() => sync.execute(trigger: SyncTrigger.automatic)).called(1);
    verifyNever(() => sync.execute(trigger: SyncTrigger.user));
    await bloc.close();
    await bloc.waitForRefresh();
  });

  test(
    'pull-to-refresh preserves failure and spinner without caller warnings',
    () async {
      final dir = await Directory.systemTemp.createTemp('refresh-logging-');
      log = Logger.replace(directory: dir);
      final getWallets = _MockGetWalletsUsecase();
      when(
        () => getWallets.execute(),
      ).thenAnswer((_) async => Ok([_syncedWallet]));
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok([_syncedWallet]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => const Err(NoWalletsFoundFailure()));
      final single = _MockSyncWalletUsecase();
      var nativePasses = 0;
      final syncGate = Completer<void>();
      when(
        () => single.execute(
          _syncedWallet,
          discover: false,
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {
        nativePasses++;
        await syncGate.future;
        throw SyncWalletException('connection');
      });
      final coordinator = SyncCoordinator(
        getWalletsUsecase: getWallets,
        syncWalletUsecase: single,
      );
      final bloc = WalletBloc(
        getWalletsUsecase: getWallets,
        checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
        watchWalletSyncEventsUsecase: _stubbedWatchers(),
        syncWalletsUsecase: SyncWalletsUsecase(coordinator),
        getUnconfirmedIncomingBalanceUsecase:
            _MockGetUnconfirmedIncomingBalanceUsecase(),
        deleteWalletUsecase: _MockDeleteWalletUsecase(),
        checkSpWalletSetupForWalletUsecase: _stubbedSpSetup(),
        checkSpScanningForWalletUsecase: _stubbedSpScanning(),
        refreshSpWalletForWalletUsecase: _stubbedSpRefresh(),
        watchSpWalletUsecase: _stubbedSpWatch(),
        checkSpFeatureGateForWalletUsecase: _stubbedSpGate(),
        checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
        getExternalTorProxyStatusUsecase: _MockExternalTorStatusUsecase(),
      );
      try {
        var refreshSettled = false;
        final refresh = bloc.refresh().whenComplete(
          () => refreshSettled = true,
        );
        await pumpEventQueue();
        expect(bloc.state.isRefreshing, isTrue);
        expect(refreshSettled, isFalse);
        syncGate.complete();
        await refresh;
        await pumpEventQueue();
        final messages = (await log.readLogs()).map((r) => r.split('\t')[2]);
        expect(
          messages.where((m) => m.contains('Sync pass finished kind=bitcoin')),
          hasLength(1),
        );
        final callerDiagnostics = messages.where(
          (m) =>
              m.contains('SyncWallets:') || m.contains('Wallet refresh sync:'),
        );
        expect(nativePasses, 1);
        expect(bloc.state.loadFailure, isA<WalletSyncFailure>());
        expect(bloc.state.isRefreshing, isFalse);
        expect(
          callerDiagnostics,
          isEmpty,
          reason:
              'The native boundary owns the failed pass; waiters must not repeat it.',
        );
      } finally {
        if (!syncGate.isCompleted) syncGate.complete();
        await bloc.close();
        coordinator.dispose();
        await log.flush();
        await dir.delete(recursive: true);
      }
    },
  );
  for (final scenario in [
    (
      'unavailable Bitcoin proxy points to Tor settings',
      ExternalTorProxyStatus.unavailable,
      WalletWarningAction.torSettings,
    ),
    (
      'available Bitcoin proxy keeps Electrum settings',
      ExternalTorProxyStatus.available,
      WalletWarningAction.electrumSettings,
    ),
    (
      'disabled Bitcoin proxy keeps Electrum settings',
      ExternalTorProxyStatus.disabled,
      WalletWarningAction.electrumSettings,
    ),
  ]) {
    test(scenario.$1, () async {
      final status = _MockExternalTorStatusUsecase();
      when(status.execute).thenAnswer((_) async => scenario.$2);
      final bloc = createBloc(status);
      addTearDown(bloc.close);

      bloc.add(
        const ElectrumSyncResultChanged(
          ElectrumSyncResult(isLiquid: false, success: false),
        ),
      );
      final state = await bloc.stream.firstWhere(
        (state) => state.warnings.isNotEmpty,
      );

      expect(state.warnings.single.action, scenario.$3);
    });
  }

  test(
    'Liquid-only failure keeps Electrum settings without checking SOCKS',
    () async {
      final status = _MockExternalTorStatusUsecase();
      final bloc = createBloc(status);
      addTearDown(bloc.close);

      bloc.add(
        const ElectrumSyncResultChanged(
          ElectrumSyncResult(isLiquid: true, success: false),
        ),
      );
      final state = await bloc.stream.firstWhere(
        (state) => state.warnings.isNotEmpty,
      );

      expect(
        state.warnings.single.action,
        WalletWarningAction.electrumSettings,
      );
      verifyNever(status.execute);
    },
  );

  test(
    'a newer success clears a warning after an older proxy check completes',
    () async {
      final status = _MockExternalTorStatusUsecase();
      final started = Completer<void>();
      final release = Completer<ExternalTorProxyStatus>();
      when(status.execute).thenAnswer((_) async {
        started.complete();
        return release.future;
      });
      final bloc = createBloc(status);
      addTearDown(bloc.close);

      bloc.add(
        const ElectrumSyncResultChanged(
          ElectrumSyncResult(isLiquid: false, success: false),
        ),
      );
      await started.future;
      final observed = <WalletState>[];
      final subscription = bloc.stream.listen(observed.add);
      final recentDecision = Completer<void>();
      final decisionSubscription = bloc.stream.listen((state) {
        if (state.warnings.isEmpty && !recentDecision.isCompleted) {
          recentDecision.complete();
        }
      });
      bloc.add(
        const ElectrumSyncResultChanged(
          ElectrumSyncResult(isLiquid: false, success: true),
        ),
      );
      await Future.any<void>([
        recentDecision.future,
        Future<void>.delayed(const Duration(milliseconds: 100)),
      ]);
      expect(recentDecision.isCompleted, isTrue);
      release.complete(ExternalTorProxyStatus.unavailable);

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await decisionSubscription.cancel();
      expect(observed.every((state) => state.warnings.isEmpty), isTrue);
      expect(bloc.state.warnings, isEmpty);
    },
  );

  test(
    'a failed wallet load is reported, not shown as an empty wallet',
    () async {
      // Before #1895 this state was invisible: WalletStatus.failure was never
      // read by the UI, so a failed load rendered a 0-sat home screen that reads
      // as "you have no wallets" rather than as an error.
      final bloc = _blocWithFailingLoad(
        const WalletStorageFailure('getWallets failed: SqliteException'),
      );
      addTearDown(bloc.close);

      bloc.add(const WalletStarted());
      await pumpEventQueue();

      expect(bloc.state.status, WalletStatus.failure);
      expect(bloc.state.loadFailure, isA<WalletStorageFailure>());
    },
  );

  test('a failed sync round is reported, not silently dropped', () async {
    // The wallets themselves load, so the list stays correct — but a refresh
    // that silently did nothing reads as a frozen screen. This also makes the
    // sync-specific card reachable: without it, WalletSyncFailure never
    // reached state.failure and the card was dead code.
    final bloc = _blocWithFailingSync(const WalletSyncFailure('sync: timeout'));
    addTearDown(bloc.close);

    bloc.add(const WalletRefreshed());
    await pumpEventQueue();

    expect(bloc.state.status, WalletStatus.success);
    expect(bloc.state.loadFailure, isA<WalletSyncFailure>());
  });

  test('a later sync event does not wipe the refresh failure', () async {
    // Each wallet's datasource fires its finished event from a `finally`, so
    // one arrives right after a failed sync. Only start and refresh own the
    // failure; this event must not clear it before the user sees it.
    final bloc = _blocWithFailingSync(const WalletSyncFailure('sync: timeout'));
    addTearDown(bloc.close);

    bloc.add(const WalletRefreshed());
    await pumpEventQueue();
    bloc.add(WalletSyncFinished(_syncedWallet));
    await pumpEventQueue();

    expect(bloc.state.loadFailure, isA<WalletSyncFailure>());
  });

  test('"no wallets yet" routes to onboarding instead of reporting', () async {
    // Not an error condition: the router redirects, so nothing is rendered.
    final bloc = _blocWithFailingLoad(const NoWalletsFoundFailure());
    addTearDown(bloc.close);

    bloc.add(const WalletStarted());
    await pumpEventQueue();

    expect(bloc.state.noWalletsFound, isTrue);
    expect(bloc.state.loadFailure, isNull);
  });
}

/// Builds a bloc whose wallet load fails, so the failure path can be driven.
WalletBloc _blocWithFailingLoad(
  WalletFailure failure, {
  SyncWalletsUsecase? sync,
}) {
  final getWallets = _MockGetWalletsUsecase();
  when(
    () => getWallets.execute(
      onlyDefaults: any(named: 'onlyDefaults'),
      onlyBitcoin: any(named: 'onlyBitcoin'),
      onlyLiquid: any(named: 'onlyLiquid'),
      sync: any(named: 'sync'),
    ),
  ).thenAnswer((_) async => Err<List<Wallet>, WalletFailure>(failure));

  return WalletBloc(
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: sync ?? _stubbedSync(),
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    checkSpWalletSetupForWalletUsecase: _stubbedSpSetup(),
    checkSpScanningForWalletUsecase: _stubbedSpScanning(),
    refreshSpWalletForWalletUsecase: _stubbedSpRefresh(),
    watchSpWalletUsecase: _stubbedSpWatch(),
    checkSpFeatureGateForWalletUsecase: _stubbedSpGate(),
    checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
    getExternalTorProxyStatusUsecase: _MockExternalTorStatusUsecase(),
  );
}

/// The three watchers, stubbed to stay silent. Every test that cares about
/// sync events drives the bloc directly instead.
WatchWalletSyncEventsUsecase _stubbedWatchers() {
  final watchers = _MockWatchWalletSyncEventsUsecase();
  when(watchers.started).thenAnswer((_) => const Stream.empty());
  when(watchers.finished).thenAnswer((_) => const Stream.empty());
  when(watchers.electrumResults).thenAnswer((_) => const Stream.empty());
  return watchers;
}

SyncWalletsUsecase _stubbedSync() {
  // mocktail needs a concrete SyncTrigger to match  against.
  registerFallbackValue(SyncTrigger.automatic);
  final sync = _MockSyncWalletsUsecase();
  when(
    () => sync.execute(trigger: any(named: 'trigger')),
  ).thenAnswer((_) async => const Ok<void, WalletFailure>(null));
  return sync;
}

/// Silent Payments stubbed off: with the feature gate closed, the SP refresh
/// settles immediately and the watcher stays silent.
CheckSpFeatureGateForWalletUsecase _stubbedSpGate() {
  final gate = _MockCheckSpFeatureGateForWalletUsecase();
  when(gate.execute).thenAnswer((_) async => false);
  return gate;
}

CheckSpWalletSetupForWalletUsecase _stubbedSpSetup() {
  final setup = _MockCheckSpWalletSetupForWalletUsecase();
  when(setup.execute).thenAnswer((_) async => const Ok(false));
  return setup;
}

CheckSpScanningForWalletUsecase _stubbedSpScanning() {
  final scanning = _MockCheckSpScanningForWalletUsecase();
  when(scanning.execute).thenReturn(false);
  return scanning;
}

RefreshSpWalletForWalletUsecase _stubbedSpRefresh() {
  final refresh = _MockRefreshSpWalletForWalletUsecase();
  when(refresh.execute).thenAnswer((_) async => const Ok(null));
  return refresh;
}

WatchSpWalletUsecase _stubbedSpWatch() {
  final watch = _MockWatchSpWalletUsecase();
  when(watch.execute).thenAnswer((_) => const Stream.empty());
  return watch;
}

/// A bloc whose wallet reads succeed but whose sync round fails, so the
/// stale-balance path can be driven.
final _syncedWallet = Wallet(
  origin: 'w1',
  label: 'Test',
  network: Network.bitcoinMainnet,
  isDefault: true,
  masterFingerprint: 'abcd1234',
  xpubFingerprint: 'abcd1234',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'desc',
  internalPublicDescriptor: 'desc',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

WalletBloc _blocWithFailingSync(WalletFailure failure) {
  final getWallets = _MockGetWalletsUsecase();
  when(
    () => getWallets.execute(
      onlyDefaults: any(named: 'onlyDefaults'),
      onlyBitcoin: any(named: 'onlyBitcoin'),
      onlyLiquid: any(named: 'onlyLiquid'),
      sync: any(named: 'sync'),
    ),
  ).thenAnswer((_) async => const Ok<List<Wallet>, WalletFailure>([]));

  registerFallbackValue(SyncTrigger.automatic);
  final sync = _MockSyncWalletsUsecase();
  when(
    () => sync.execute(trigger: any(named: 'trigger')),
  ).thenAnswer((_) async => Err<void, WalletFailure>(failure));

  final syncing = _MockCheckWalletSyncingUsecase();
  when(
    () => syncing.execute(walletId: any(named: 'walletId')),
  ).thenReturn(const Ok<bool, WalletFailure>(false));

  return WalletBloc(
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: syncing,
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: sync,
    getUnconfirmedIncomingBalanceUsecase:
        _MockGetUnconfirmedIncomingBalanceUsecase(),
    deleteWalletUsecase: _MockDeleteWalletUsecase(),
    checkSpWalletSetupForWalletUsecase: _stubbedSpSetup(),
    checkSpScanningForWalletUsecase: _stubbedSpScanning(),
    refreshSpWalletForWalletUsecase: _stubbedSpRefresh(),
    watchSpWalletUsecase: _stubbedSpWatch(),
    checkSpFeatureGateForWalletUsecase: _stubbedSpGate(),
    checkBackupNeededUsecase: _MockCheckBackupNeededUsecase(),
    getExternalTorProxyStatusUsecase: _MockExternalTorStatusUsecase(),
  );
}
