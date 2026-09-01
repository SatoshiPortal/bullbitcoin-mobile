import 'package:primitives/primitives.dart';
import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Captures any error a bloc handler forwards to onError, so a test can assert
// a throw was handled inside the handler rather than escaping.
class _CapturingBlocObserver extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockCheckWalletSyncingUsecase extends Mock
    implements CheckWalletSyncingUsecase {}

class _MockCheckBackupNeeded extends Mock implements CheckBackupNeededUsecase {}

class _MockWatchStarted extends Mock
    implements WatchStartedWalletSyncsUsecase {}

class _MockWatchFinished extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockWatchElectrumSyncResults extends Mock
    implements WatchElectrumSyncResultsUsecase {}

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

class _MockGetUnconfirmed extends Mock
    implements GetUnconfirmedIncomingBalanceUsecase {}

class _MockDeleteWallet extends Mock implements DeleteWalletUsecase {}

class _MockRefreshSpWalletForWallet extends Mock
    implements RefreshSpWalletForWalletUsecase {}

class _MockCheckSpWalletSetupForWallet extends Mock
    implements CheckSpWalletSetupForWalletUsecase {}

class _MockCheckSpScanningForWallet extends Mock
    implements CheckSpScanningForWalletUsecase {}

class _MockSeedStoreType extends Mock implements SeedStoreTypeDatasource {}

class _MockExternalTorStatus extends Mock
    implements GetExternalTorProxyStatusUsecase {}

class _MockCheckSpFeatureGate extends Mock
    implements CheckSpFeatureGateForWalletUsecase {}

class _MockWatchSpWallet extends Mock implements WatchSpWalletUsecase {}

SpWallet _spWallet(int confirmedSat, {int? totalUnifiedSat}) => SpWallet(
  spAddress: 'sp1qexample',
  balance: SpBalance(
    confirmedSat: Sats.fromInt(confirmedSat),
    totalUnifiedSat: Sats.fromInt(totalUnifiedSat ?? confirmedSat),
  ),
  isScanning: false,
);

WalletBloc _makeBloc({
  required _MockRefreshSpWalletForWallet refreshSp,
  _MockGetWalletsUsecase? getWallets,
  _MockSyncCoordinator? syncCoordinator,
  _MockCheckSpWalletSetupForWallet? checkSetup,
  _MockCheckSpScanningForWallet? checkScanning,
  // The SP update stream the bloc subscribes to in `_onStarted`. Defaults to
  // an empty stream so existing tests (which never dispatch `WalletStarted`,
  // or do so without expecting SP-driven dispatches) are unaffected.
  Stream<SpUpdate> spUpdates = const Stream<SpUpdate>.empty(),
  // The superuser + dev mode feature gate. Defaults on so existing tests see
  // the SP card enabled.
  bool gateEnabled = true,
}) {
  checkSetup ??= _MockCheckSpWalletSetupForWallet();
  checkScanning ??= _MockCheckSpScanningForWallet();
  final watchStarted = _MockWatchStarted();
  final watchFinished = _MockWatchFinished();
  final watchElectrum = _MockWatchElectrumSyncResults();
  final watchSp = _MockWatchSpWallet();
  final useDefaultGetWallets = getWallets == null;
  getWallets ??= _MockGetWalletsUsecase();
  syncCoordinator ??= _MockSyncCoordinator();
  final checkWalletSyncing = _MockCheckWalletSyncingUsecase();
  final seedStoreType = _MockSeedStoreType();

  when(
    () => watchStarted.execute(),
  ).thenAnswer((_) => const Stream<Wallet>.empty());
  when(
    () => watchFinished.execute(),
  ).thenAnswer((_) => const Stream<Wallet>.empty());
  when(
    () => watchElectrum.execute(),
  ).thenAnswer((_) => const Stream<ElectrumSyncResult>.empty());
  when(() => watchSp.execute()).thenAnswer((_) => spUpdates);
  // Default: not scanning. Tests that need the scan-gate override this.
  when(() => checkScanning!.execute()).thenReturn(false);

  // Stubs so a dispatched `WalletStarted` doesn't throw. Existing tests never
  // dispatch it, so these are harmless; SP-stream tests rely on them.
  if (useDefaultGetWallets) {
    when(
      () => getWallets!.execute(sync: any(named: 'sync')),
    ).thenAnswer((_) async => <Wallet>[]);
  }
  when(
    () => checkWalletSyncing.execute(walletId: any(named: 'walletId')),
  ).thenReturn(false);
  when(() => checkWalletSyncing.execute()).thenReturn(false);
  when(() => seedStoreType.read()).thenAnswer((_) async => null);

  final checkSpFeatureGate = _MockCheckSpFeatureGate();
  when(() => checkSpFeatureGate.execute()).thenAnswer((_) async => gateEnabled);

  return WalletBloc(
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: checkWalletSyncing,
    checkBackupNeededUsecase: _MockCheckBackupNeeded(),
    watchStartedWalletSyncsUsecase: watchStarted,
    watchFinishedWalletSyncsUsecase: watchFinished,
    watchElectrumSyncResultsUsecase: watchElectrum,
    syncCoordinator: syncCoordinator,
    getUnconfirmedIncomingBalanceUsecase: _MockGetUnconfirmed(),
    deleteWalletUsecase: _MockDeleteWallet(),
    getExternalTorProxyStatusUsecase: _MockExternalTorStatus(),
    checkSpWalletSetupForWalletUsecase: checkSetup,
    checkSpScanningForWalletUsecase: checkScanning,
    refreshSpWalletForWalletUsecase: refreshSp,
    watchSpWalletUsecase: watchSp,
    seedStoreTypeDatasource: seedStoreType,
    checkSpFeatureGateForWalletUsecase: checkSpFeatureGate,
  );
}

// Dispatches [event] and drains the microtask queue so the async handler runs
// to completion. Replaces the copy-pasted add + pumpEventQueue dance.
Future<void> drive(WalletBloc bloc, WalletEvent event) async {
  bloc.add(event);
  await pumpEventQueue(times: 100);
}

// Same, but records every state emitted while the handler runs, for tests that
// assert on the emission sequence rather than just the final state.
Future<List<WalletState>> driveCollecting(
  WalletBloc bloc,
  WalletEvent event,
) async {
  final states = <WalletState>[];
  final sub = bloc.stream.listen(states.add);
  await drive(bloc, event);
  await sub.cancel();
  return states;
}

void main() {
  group('WalletBloc SP: RefreshSpWallet handler', () {
    test(
      'spBalanceSat set in state when setup=true and wallet loaded',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        final wallet = _spWallet(5000);

        when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
        when(() => refreshSp.execute()).thenAnswer((_) async => Ok(wallet));

        final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

        final states = await driveCollecting(bloc, const RefreshSpWallet());

        expect(states, isNotEmpty);
        final finalState = states.last;
        expect(finalState.spBalanceSat, 5000);
        expect(finalState.isSpWalletLoading, isFalse);
        expect(finalState.isSpWalletSetup, isTrue);

        await bloc.close();
      },
    );

    test('loaded SP wallet uses unified total for home balance', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final wallet = _spWallet(0, totalUnifiedSat: 5000);

      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(wallet));

      final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

      await drive(bloc, const RefreshSpWallet());

      expect(bloc.state.spBalanceSat, 5000);
      expect(bloc.state.totalBalance(), 5000);

      await bloc.close();
    });

    test('isSpWalletSetup=false and no wallet when not set up', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();

      // Not set up: setup check false, refresh returns null (gated/revoked).
      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(false));
      when(
        () => refreshSp.execute(),
      ).thenAnswer((_) async => const Ok<SpWallet?, SpFailure>(null));

      final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

      final states = await driveCollecting(bloc, const RefreshSpWallet());

      expect(states, isNotEmpty);
      final finalState = states.last;
      expect(finalState.isSpWalletSetup, isFalse);
      expect(finalState.spBalanceSat, 0);
      expect(finalState.isSpWalletLoading, isFalse);

      await bloc.close();
    });

    test('gate off emits isSpFeatureEnabled=false even when set up (SP card '
        'stays hidden)', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final wallet = _spWallet(5000);

      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(wallet));

      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        gateEnabled: false,
      );

      final states = await driveCollecting(bloc, const RefreshSpWallet());

      // The card gates on isSpFeatureEnabled && isSpWalletSetup; a gate off
      // hides it regardless of setup.
      expect(states.last.isSpFeatureEnabled, isFalse);
      expect(states.last.isSpWalletSetup, isTrue);
      expect(states.last.showSpWallet, isFalse);

      await bloc.close();
    });

    test('a hidden SP wallet is left out of the home total', () async {
      // The balance is still mirrored (a live session keeps pushing it), so the
      // total is what must exclude it. Counting sats the user cannot see any
      // card for would be money appearing from nowhere.
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();

      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(
        () => refreshSp.execute(),
      ).thenAnswer((_) async => Ok(_spWallet(5000)));

      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        gateEnabled: false,
      );

      await driveCollecting(bloc, const RefreshSpWallet());
      bloc.add(const SetSpWalletBalance(5000));
      await pumpEventQueue();

      expect(bloc.state.spBalanceSat, 5000);
      expect(bloc.state.showSpWallet, isFalse);
      expect(
        bloc.state.totalBalance(),
        0,
        reason: 'a wallet with no visible card must not move the total',
      );

      await bloc.close();
    });

    test('isSpWalletSetup reflects the setup check', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final wallet = _spWallet(200);

      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(wallet));

      final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

      await drive(bloc, const RefreshSpWallet());

      expect(bloc.state.isSpWalletSetup, isTrue);
      expect(bloc.state.spBalanceSat, 200);
      expect(bloc.state.isSpWalletLoading, isFalse);
      verify(() => refreshSp.execute()).called(1);

      await bloc.close();
    });

    test('refresh failing leaves state and clears loading', () async {
      // refresh can throw an FFI error while reading the snapshot. The bloc
      // must leave the existing snapshot intact and clear the loading flag.
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final wallet = _spWallet(7777);

      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(wallet));

      final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

      // Prime state with a loaded wallet.
      await drive(bloc, const RefreshSpWallet());
      expect(bloc.state.spBalanceSat, 7777);

      // Now make refresh fail.
      when(() => refreshSp.execute()).thenAnswer(
        (_) async => const Err(SpUnexpected('FFI error reading SP snapshot')),
      );

      await drive(bloc, const RefreshSpWallet());

      // State left intact; loading cleared so the UI doesn't get stuck.
      expect(
        bloc.state.spBalanceSat,
        7777,
        reason: 'balance must reflect the stale wallet, not be reset',
      );
      expect(bloc.state.isSpWalletLoading, isFalse);

      await bloc.close();
    });

    test('a failed setup check settles the card without an unhandled '
        'bloc error', () async {
      final previousObserver = Bloc.observer;
      final observer = _CapturingBlocObserver();
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = previousObserver);

      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      when(
        () => checkSetup.execute(),
      ).thenAnswer((_) async => const Err(SpUnexpected('setup check boom')));

      final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

      await drive(bloc, const RefreshSpWallet());

      expect(
        observer.errors,
        isEmpty,
        reason: 'a setup-check failure must settle in the handler, not escape',
      );
      // The card settled to a non-loading state; refresh never ran.
      expect(bloc.state.isSpWalletLoading, isFalse);
      verifyNever(() => refreshSp.execute());

      await bloc.close();
    });

    test('refresh skipped while a scan is running', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final checkScanning = _MockCheckSpScanningForWallet();
      final wallet = _spWallet(3000);

      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(wallet));

      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        checkScanning: checkScanning,
      );

      // Prime with a loaded wallet (not scanning).
      await drive(bloc, const RefreshSpWallet());
      expect(bloc.state.spBalanceSat, 3000);

      // Now a scan is running: the next refresh must skip (no dispose/snapshot).
      when(() => checkScanning.execute()).thenReturn(true);
      clearInteractions(refreshSp);

      await drive(bloc, const RefreshSpWallet());

      expect(bloc.state.spBalanceSat, 3000);
      verifyNever(() => refreshSp.execute());

      await bloc.close();
    });

    test(
      'newer RefreshSpWallet result wins over an older in-flight refresh',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        final firstRefresh = Completer<Result<SpWallet?, SpFailure>>();
        final secondRefresh = Completer<Result<SpWallet?, SpFailure>>();
        var refreshCount = 0;

        when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
        when(() => refreshSp.execute()).thenAnswer((_) {
          refreshCount++;
          return refreshCount == 1 ? firstRefresh.future : secondRefresh.future;
        });

        final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

        bloc.add(const RefreshSpWallet());
        await pumpEventQueue(times: 100);
        bloc.add(const RefreshSpWallet());
        await pumpEventQueue(times: 100);

        secondRefresh.complete(Ok(_spWallet(2000)));
        await pumpEventQueue(times: 100);
        firstRefresh.complete(Ok(_spWallet(1000)));
        await pumpEventQueue(times: 100);

        expect(bloc.state.spBalanceSat, 2000);

        await bloc.close();
      },
    );

    test(
      'stale full refresh does not overwrite a newer balance update',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        final gate = Completer<Result<SpWallet?, SpFailure>>();

        when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
        when(() => refreshSp.execute()).thenAnswer((_) => gate.future);

        final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

        bloc.add(const RefreshSpWallet());
        await pumpEventQueue(times: 100);

        bloc.add(const SetSpWalletBalance(9876));
        await pumpEventQueue(times: 100);

        gate.complete(Ok(_spWallet(0)));
        await pumpEventQueue(times: 100);

        expect(bloc.state.spBalanceSat, 9876);
        expect(bloc.state.totalBalance(), 9876);

        await bloc.close();
      },
    );
  });

  group('WalletBloc SP: observed update stream', () {
    test(
      'subscribes to SP updates before startup wallet loading finishes',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        final getWallets = _MockGetWalletsUsecase();
        final walletsLoaded = Completer<List<Wallet>>();

        when(
          () => getWallets.execute(sync: any(named: 'sync')),
        ).thenAnswer((_) => walletsLoaded.future);
        when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
        when(
          () => refreshSp.execute(),
        ).thenAnswer((_) async => Ok(_spWallet(0)));

        final controller = StreamController<SpUpdate>.broadcast();
        addTearDown(controller.close);

        final bloc = _makeBloc(
          refreshSp: refreshSp,
          checkSetup: checkSetup,
          getWallets: getWallets,
          spUpdates: controller.stream,
        );

        bloc.add(const WalletStarted());
        await pumpEventQueue(times: 100);

        final balanced = bloc.stream.firstWhere((s) => s.spBalanceSat == 9876);
        controller.add(SpBalanceChanged(Sats.fromInt(9876)));

        await balanced;
        expect(bloc.state.spBalanceSat, 9876);

        walletsLoaded.complete(<Wallet>[]);
        await pumpEventQueue(times: 100);
        await bloc.close();
      },
    );

    test(
      'WalletStarted keeps the current SP balance while reloading wallets',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        final refreshLoaded = Completer<Result<SpWallet?, SpFailure>>();

        when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
        when(() => refreshSp.execute()).thenAnswer((_) => refreshLoaded.future);

        final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);
        await drive(bloc, const SetSpWalletBalance(9876));

        final states = <WalletState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const WalletStarted());
        await pumpEventQueue(times: 100);

        final startupState = states.firstWhere(
          (state) => state.status == WalletStatus.success,
        );
        expect(startupState.spBalanceSat, 9876);

        refreshLoaded.complete(Ok(_spWallet(9876)));
        await pumpEventQueue(times: 100);
        await sub.cancel();
        await bloc.close();
      },
    );

    test('SpBalanceChanged drives the amount fast-path (no refresh)', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      // Stubbed but must NOT be consulted on a pure balance change.
      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(_spWallet(0)));

      final controller = StreamController<SpUpdate>.broadcast();
      addTearDown(controller.close);

      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        spUpdates: controller.stream,
      );

      // Let _onStarted run far enough to subscribe to the SP stream and to
      // settle the full-path refreshes it dispatches on startup.
      await drive(bloc, const WalletStarted());

      // Reset interactions from the WalletStarted full pass so we can assert
      // the balance event itself triggers NO full re-evaluate.
      clearInteractions(refreshSp);
      clearInteractions(checkSetup);

      final balanced = bloc.stream.firstWhere((s) => s.spBalanceSat == 9876);

      controller.add(SpBalanceChanged(Sats.fromInt(9876)));

      await balanced;
      expect(bloc.state.spBalanceSat, 9876);

      // The amount fast-path must not consult the facade at all.
      verifyNever(() => checkSetup.execute());
      verifyNever(() => refreshSp.execute());

      await bloc.close();
    });

    test('SpBalanceChanged amount is included in total balance', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(_spWallet(0)));

      final controller = StreamController<SpUpdate>.broadcast();
      addTearDown(controller.close);

      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        spUpdates: controller.stream,
      );

      await drive(bloc, const WalletStarted());

      final balanced = bloc.stream.firstWhere((s) => s.spBalanceSat == 9876);
      controller.add(SpBalanceChanged(Sats.fromInt(9876)));

      await balanced;
      expect(bloc.state.totalBalance(), 9876);

      await bloc.close();
    });

    test('SpSetupChanged drives a full re-evaluate', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final wallet = _spWallet(4321);
      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(wallet));

      final controller = StreamController<SpUpdate>.broadcast();
      addTearDown(controller.close);

      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        spUpdates: controller.stream,
      );

      await drive(bloc, const WalletStarted());

      // Reset interactions from the WalletStarted full pass so we can assert
      // the setup-change event triggers its own full re-evaluate.
      clearInteractions(refreshSp);
      clearInteractions(checkSetup);

      final loaded = bloc.stream.firstWhere((s) => s.spBalanceSat == 4321);

      controller.add(const SpSetupChanged());

      await loaded;
      expect(bloc.state.isSpWalletSetup, isTrue);
      expect(bloc.state.spBalanceSat, 4321);
      verify(() => checkSetup.execute()).called(1);
      verify(() => refreshSp.execute()).called(1);

      await bloc.close();
    });
  });
}
