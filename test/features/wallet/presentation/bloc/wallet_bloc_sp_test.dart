import 'package:overview/overview.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:primitives/primitives.dart' hide Network;

import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';

import 'package:electrum/electrum.dart';
import 'package:overview/setup.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_external_tor_proxy_status_usecase.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
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

class _MockWatchStarted extends Mock
    implements WatchStartedWalletSyncsUsecase {}

class _MockWatchFinished extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

abstract interface class _ElectrumResults {
  Stream<ElectrumSyncResult> execute();
}

class _MockWatchElectrumSyncResults extends Mock implements _ElectrumResults {}

class _MockSyncCoordinator extends Mock
    implements SyncCoordinator<Wallet, WalletFailure> {}

class _MockGetUnconfirmed extends Mock implements OngoingSwaps {}

abstract interface class _Read<T> {
  T execute();
}

class _MockRefreshSpWalletForWallet extends Mock
    implements _Read<Future<Result<SilentWallet?, WalletFailure>>> {}

class _MockCheckSpWalletSetupForWallet extends Mock
    implements _Read<Future<Result<bool, WalletFailure>>> {}

class _MockCheckSpScanningForWallet extends Mock implements _Read<bool> {}

class _MockExternalTorStatus extends Mock
    implements GetExternalTorProxyStatusUsecase {}

class _HomeSilent extends Fake implements Silent {
  final _MockRefreshSpWalletForWallet read;
  final _MockCheckSpWalletSetupForWallet setup;
  final _MockCheckSpScanningForWallet scanning;
  final Stream<SilentUpdate> updates;
  final bool enabled;
  final bool unreadable;
  _HomeSilent(
    this.read,
    this.setup,
    this.scanning,
    this.updates,
    this.enabled,
    this.unreadable,
  );

  @override
  Future<Result<bool, SilentFailure>> isFeatureEnabled() async =>
      unreadable ? const Err(SilentUnexpected('unreadable')) : Ok(enabled);
  @override
  Future<Result<bool, SilentFailure>> isSetUp() async =>
      (await setup.execute()).mapErr((_) => const SilentUnexpected('setup'));
  @override
  bool get isScanning => scanning.execute();
  @override
  Future<Result<SilentWallet?, SilentFailure>> refresh() async =>
      (await read.execute()).mapErr((_) => const SilentUnexpected('read'));
  @override
  Stream<Result<SilentUpdate, SilentFailure>> watchUpdates() =>
      updates.map(Ok.new);
}

// Keep the race regression runnable on the pre-provenance constructor too.
// Both versions receive the same public snapshot data; assertions are identical.
SilentWallet _spWallet(
  int confirmedSat, {
  int? totalUnifiedSat,
  BitcoinNetwork network = BitcoinNetwork.mainnet,
}) {
  final balance = SilentBalance(
    confirmedSat: Sats.fromInt(confirmedSat),
    totalUnifiedSat: Sats.fromInt(totalUnifiedSat ?? confirmedSat),
  );
  try {
    return Function.apply(SilentWallet.new, const [], {
      #network: network,
      #spAddress: 'sp1qexample',
      #balance: balance,
      #isScanning: false,
    }) as SilentWallet;
  } on NoSuchMethodError {
    return SilentWallet(
      spAddress: 'sp1qexample',
      balance: balance,
      isScanning: false,
    );
  }
}

class _CatalogWallet extends Mock implements Wallet {}

Wallet _pendingCatalogTarget() {
  final wallet = _CatalogWallet();
  when(() => wallet.id).thenReturn('pending-catalog-target');
  when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
  when(() => wallet.balanceSat).thenReturn(BigInt.from(100));
  when(() => wallet.isDefault).thenReturn(false);
  when(() => wallet.unavailable).thenReturn(false);
  return wallet;
}

WalletBloc _makeBloc({
  required _MockRefreshSpWalletForWallet refreshSp,
  _MockGetWalletsUsecase? getWallets,
  _MockSyncCoordinator? syncCoordinator,
  _MockCheckSpWalletSetupForWallet? checkSetup,
  _MockCheckSpScanningForWallet? checkScanning,
  // The SP update stream the bloc subscribes to in `_onStarted`. Defaults to
  // an empty stream so existing tests (which never dispatch `WalletStarted`,
  // or do so without expecting SP-driven dispatches) are unaffected.
  Stream<SilentUpdate> spUpdates = const Stream<SilentUpdate>.empty(),
  // The superuser + dev mode feature gate. Defaults on so existing tests see
  // the SP card enabled.
  bool gateEnabled = true,
  WalletFailure? gateFailure,
}) {
  checkSetup ??= _MockCheckSpWalletSetupForWallet();
  checkScanning ??= _MockCheckSpScanningForWallet();
  final watchStarted = _MockWatchStarted();
  final watchFinished = _MockWatchFinished();
  final watchElectrum = _MockWatchElectrumSyncResults();
  final useDefaultGetWallets = getWallets == null;
  getWallets ??= _MockGetWalletsUsecase();
  syncCoordinator ??= _MockSyncCoordinator();
  final checkWalletSyncing = _MockCheckWalletSyncingUsecase();
  when(() => watchStarted.execute())
      .thenAnswer((_) => const Stream<String>.empty());
  when(() => watchFinished.execute())
      .thenAnswer((_) => const Stream<Wallet>.empty());
  when(() => watchElectrum.execute())
      .thenAnswer((_) => const Stream<ElectrumSyncResult>.empty());
  // Default: not scanning. Tests that need the scan-gate override this.
  when(() => checkScanning!.execute()).thenReturn(false);

  // Stubs so a dispatched `WalletStarted` doesn't throw. Existing tests never
  // dispatch it, so these are harmless; SP-stream tests rely on them.
  if (useDefaultGetWallets) {
    when(() => getWallets!.execute(sync: any(named: 'sync')))
        .thenAnswer((_) async => const Ok(<Wallet>[]));
  }
  when(() => checkWalletSyncing.execute(walletId: any(named: 'walletId')))
      .thenReturn(const Ok(false));
  when(() => checkWalletSyncing.execute()).thenReturn(const Ok(false));

  return WalletBloc(
    readWalletUsecase: _ReadWallet(),
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: checkWalletSyncing,
    readBackupWarning: () async => null,
    // The real wrappers over the same mocks, so assertions on the
    // coordinator and watchers still hold.
    watchWalletSyncEventsUsecase: WatchWalletSyncEventsUsecase(
      watchStarted: watchStarted,
      watchFinished: watchFinished,
      watchElectrum: watchElectrum.execute,
    ),
    syncWalletsUsecase: SyncWalletsUsecase(syncCoordinator.sync),
    ongoingSwaps: _MockGetUnconfirmed(),
    getExternalTorProxyStatusUsecase: _MockExternalTorStatus(),
    silentHome: SilentHomeObservation(
      _HomeSilent(
        refreshSp,
        checkSetup,
        checkScanning,
        spUpdates,
        gateEnabled,
        gateFailure != null,
      ),
    ),
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
      'feature gate failure persists a fixed warning without foreign text',
      () async {
        final directory = await Directory.systemTemp.createTemp('sp-gate-log-');
        await initializeLogging(directory: directory);
        addTearDown(() async {
          await log.flush();
          await directory.delete(recursive: true);
        });
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        when(() => checkSetup.execute())
            .thenAnswer((_) async => const Ok(false));
        when(
          () => refreshSp.execute(),
        ).thenAnswer((_) async => const Ok<SilentWallet?, WalletFailure>(null));
        final bloc = _makeBloc(
          refreshSp: refreshSp,
          checkSetup: checkSetup,
          gateFailure: const WalletStorageFailure('foreign-gate-sentinel'),
        );
        addTearDown(bloc.close);

        await drive(bloc, const RefreshSpWallet());

        final lines = await log.readLogs();
        final warnings = lines
            .map((line) => line.split('\t'))
            .where((row) => row[1] == 'WARNING');
        expect(
          warnings.map((row) => row[2]),
          contains('SP feature gate refresh failed category=feature_gate'),
        );
        expect(lines.join('\n'), isNot(contains('foreign-gate-sentinel')));
      },
    );

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
      ).thenAnswer((_) async => const Ok<SilentWallet?, WalletFailure>(null));

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
      verifyNever(() => refreshSp.execute());

      await bloc.close();
    });

    test('a hidden SP wallet is left out of the home total', () async {
      // Untagged notifications cannot authorize an amount while the gate is closed.
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();

      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute())
          .thenAnswer((_) async => Ok(_spWallet(5000)));

      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        gateEnabled: false,
      );

      await driveCollecting(bloc, const RefreshSpWallet());
      bloc.add(const SetSpWalletBalance(5000));
      await pumpEventQueue();

      expect(bloc.state.spBalanceSat, 0);
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

    test('refresh failing hides unproven balance and clears loading', () async {
      // An unreadable snapshot must not keep a visible, unproven balance.
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
        (_) async =>
            const Err(WalletStorageFailure('FFI error reading SP snapshot')),
      );

      await drive(bloc, const RefreshSpWallet());

      // Fail closed and settle loading.
      expect(
        bloc.state.spBalanceSat,
        0,
        reason: 'a failed admission must not keep a spendable visible balance',
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
      when(() => checkSetup.execute()).thenAnswer(
        (_) async => const Err(WalletStorageFailure('setup check boom')),
      );

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
        final firstRefresh = Completer<Result<SilentWallet?, WalletFailure>>();
        final secondRefresh = Completer<Result<SilentWallet?, WalletFailure>>();
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

    test('untagged amount cannot override a guarded snapshot', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final gate = Completer<Result<SilentWallet?, WalletFailure>>();

      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) => gate.future);

      final bloc = _makeBloc(refreshSp: refreshSp, checkSetup: checkSetup);

      bloc.add(const RefreshSpWallet());
      await pumpEventQueue(times: 100);

      bloc.add(const SetSpWalletBalance(9876));
      await pumpEventQueue(times: 100);

      gate.complete(Ok(_spWallet(0)));
      await pumpEventQueue(times: 100);

      expect(bloc.state.spBalanceSat, 0);
      expect(bloc.state.totalBalance(), 0);

      await bloc.close();
    });
  });

  group('WalletBloc SP: observed update stream', () {
    test('closing retires a pending Home read and cancels updates', () async {
      final refresh = _MockRefreshSpWalletForWallet();
      final setup = _MockCheckSpWalletSetupForWallet();
      final pending = Completer<Result<SilentWallet?, WalletFailure>>();
      var cancelled = false;
      final updates = StreamController<SilentUpdate>(
        onCancel: () => cancelled = true,
      );
      addTearDown(updates.close);
      when(setup.execute).thenAnswer((_) async => const Ok(true));
      when(refresh.execute).thenAnswer((_) => pending.future);
      final bloc = _makeBloc(
        refreshSp: refresh,
        checkSetup: setup,
        spUpdates: updates.stream,
      );
      await drive(bloc, const WalletStarted());
      verify(refresh.execute).called(greaterThan(0));
      final closing = bloc.close();
      await pumpEventQueue();
      expect(cancelled, isTrue);
      pending.complete(Ok(_spWallet(9000)));
      await closing;
      expect(bloc.state.showSpWallet, isFalse);
      expect(bloc.state.totalBalance(), 0);
    });

    test(
      'subscribes to SP updates before startup wallet loading finishes',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        final getWallets = _MockGetWalletsUsecase();
        final walletsLoaded = Completer<Result<List<Wallet>, WalletFailure>>();

        when(() => getWallets.execute(sync: any(named: 'sync')))
            .thenAnswer((_) => walletsLoaded.future);
        when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
        when(() => refreshSp.execute())
            .thenAnswer((_) async => Ok(_spWallet(0)));

        final controller = StreamController<SilentUpdate>.broadcast();
        addTearDown(controller.close);

        final bloc = _makeBloc(
          refreshSp: refreshSp,
          checkSetup: checkSetup,
          getWallets: getWallets,
          spUpdates: controller.stream,
        );

        bloc.add(const WalletStarted());
        await pumpEventQueue(times: 100);

        controller.add(SilentBalanceChanged(Sats.fromInt(9876)));
        await pumpEventQueue(times: 100);
        expect(bloc.state.showSpWallet, isFalse);
        expect(bloc.state.totalBalance(), 0);
        verifyNever(() => refreshSp.execute());

        walletsLoaded.complete(const Ok(<Wallet>[]));
        await pumpEventQueue(times: 100);
        await bloc.close();
      },
    );

    for (final oldNetwork in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
      for (final scanning in [false, true]) {
        test(
          'old $oldNetwork snapshot and notification cannot enter new TOTAL scanning=$scanning',
          () async {
            final refresh = _MockRefreshSpWalletForWallet();
            final setup = _MockCheckSpWalletSetupForWallet();
            final scan = _MockCheckSpScanningForWallet();
            final wallets = _MockGetWalletsUsecase();
            final oldResult = Completer<Result<SilentWallet?, WalletFailure>>();
            when(() => setup.execute()).thenAnswer((_) async => const Ok(true));
            when(
              () => refresh.execute(),
            ).thenAnswer((_) async => Ok(_spWallet(9000, network: oldNetwork)));
            final bloc = _makeBloc(
              refreshSp: refresh,
              checkSetup: setup,
              checkScanning: scan,
              getWallets: wallets,
            );
            await drive(bloc, const RefreshSpWallet());
            expect(bloc.state.totalBalance(), 9000);
            when(() => refresh.execute()).thenAnswer((_) => oldResult.future);
            bloc.add(const RefreshSpWallet());
            await pumpEventQueue(times: 100);
            final target = _CatalogWallet();
            final targetNetwork = oldNetwork == BitcoinNetwork.mainnet
                ? Network.bitcoinTestnet
                : Network.bitcoinMainnet;
            when(() => target.id).thenReturn('target');
            when(() => target.network).thenReturn(targetNetwork);
            when(() => target.balanceSat).thenReturn(BigInt.from(100));
            when(() => target.isDefault).thenReturn(false);
            when(() => target.unavailable).thenReturn(false);
            when(() => wallets.execute(sync: any(named: 'sync')))
                .thenAnswer((_) async => Ok([target]));
            final states = <WalletState>[];
            final sub = bloc.stream.listen(states.add);
            when(() => scan.execute()).thenReturn(scanning);
            when(() => refresh.execute()).thenAnswer(
              (_) async => const Err(WalletStorageFailure('inactive snapshot')),
            );
            await drive(bloc, const WalletStarted());
            bloc.add(const SetSpWalletBalance(9000));
            oldResult.complete(Ok(_spWallet(9000, network: oldNetwork)));
            await pumpEventQueue(times: 100);
            final published = states.where(
              (s) => s.wallets.any((w) => w.id == 'target'),
            );
            expect(published, isNotEmpty);
            expect(
              published.every(
                (s) => !s.showSpWallet && s.totalBalance() == 100,
              ),
              isTrue,
            );
            expect(bloc.state.totalBalance(), 100);
            await sub.cancel();
            await bloc.close();
          },
        );
      }
    }

    test(
      'Refreshed publication releases superseded Started admission',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final setup = _MockCheckSpWalletSetupForWallet();
        final getWallets = _MockGetWalletsUsecase();
        final sync = _MockSyncCoordinator();
        final startedRead = Completer<Result<List<Wallet>, WalletFailure>>();
        final target = _pendingCatalogTarget();
        var reads = 0;
        when(() => setup.execute()).thenAnswer((_) async => const Ok(true));
        when(() => refreshSp.execute())
            .thenAnswer((_) async => Ok(_spWallet(9000)));
        when(() => sync.sync(trigger: SyncTrigger.automatic))
            .thenAnswer((_) async {});
        when(() => getWallets.execute(sync: any(named: 'sync'))).thenAnswer((
          _,
        ) {
          reads++;
          return reads == 1 ? startedRead.future : Future.value(Ok([target]));
        });
        final bloc = _makeBloc(
          refreshSp: refreshSp,
          checkSetup: setup,
          getWallets: getWallets,
          syncCoordinator: sync,
        );
        addTearDown(bloc.close);
        bloc.add(const WalletStarted());
        await pumpEventQueue(times: 100);
        expect(reads, 1);
        expect(bloc.state.showSpWallet, isFalse);

        // A distinct droppable bucket publishes its changed catalogue first.
        await drive(bloc, const WalletRefreshed());
        expect(bloc.state.wallets.single.id, target.id);
        expect(bloc.state.showSpWallet, isTrue);
        expect(bloc.state.totalBalance(), 9100);

        // The old Started result must not replace that catalogue or wedge SP.
        startedRead.complete(const Ok(<Wallet>[]));
        await pumpEventQueue(times: 100);
        clearInteractions(refreshSp);
        await drive(bloc, const RefreshSpWallet());
        expect(bloc.state.wallets.single.id, target.id);
        expect(bloc.state.showSpWallet, isTrue);
        expect(bloc.state.totalBalance(), 9100);
        verify(() => refreshSp.execute()).called(1);
      },
    );

    test('stale Started cannot release a newer Started admission', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final setup = _MockCheckSpWalletSetupForWallet();
      final getWallets = _MockGetWalletsUsecase();
      final sync = _MockSyncCoordinator();
      final oldRead = Completer<Result<List<Wallet>, WalletFailure>>();
      final newRead = Completer<Result<List<Wallet>, WalletFailure>>();
      final target = _pendingCatalogTarget();
      var reads = 0;
      when(() => setup.execute()).thenAnswer((_) async => const Ok(true));
      when(() => refreshSp.execute())
          .thenAnswer((_) async => Ok(_spWallet(9000)));
      when(() => sync.sync(trigger: SyncTrigger.automatic))
          .thenAnswer((_) async {});
      when(() => getWallets.execute(sync: any(named: 'sync'))).thenAnswer((_) {
        reads++;
        return switch (reads) {
          1 => oldRead.future,
          2 => newRead.future,
          _ => Future.value(Ok([target])),
        };
      });
      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: setup,
        getWallets: getWallets,
        syncCoordinator: sync,
      );
      addTearDown(bloc.close);
      bloc.add(const WalletStarted());
      await pumpEventQueue(times: 100);
      bloc.add(const WalletStarted());
      await pumpEventQueue(times: 100);
      expect(reads, 2);

      oldRead.complete(const Ok(<Wallet>[]));
      await pumpEventQueue(times: 100);
      await drive(bloc, const RefreshSpWallet());
      expect(bloc.state.showSpWallet, isFalse);
      verifyNever(() => refreshSp.execute());

      newRead.complete(Ok([target]));
      await pumpEventQueue(times: 100);
      expect(bloc.state.wallets.single.id, target.id);
      expect(bloc.state.showSpWallet, isTrue);
      expect(bloc.state.totalBalance(), 9100);
    });

    test('catalog transition hides SP before pending reads complete', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final getWallets = _MockGetWalletsUsecase();
      final catalog = Completer<Result<List<Wallet>, WalletFailure>>();
      when(() => checkSetup.execute()).thenAnswer((_) async => const Ok(true));
      when(() => refreshSp.execute())
          .thenAnswer((_) async => Ok(_spWallet(9876)));
      when(() => getWallets.execute(sync: any(named: 'sync')))
          .thenAnswer((_) => catalog.future);
      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        getWallets: getWallets,
      );
      await drive(bloc, const RefreshSpWallet());
      expect(bloc.state.totalBalance(), 9876);
      final states = <WalletState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const WalletStarted());
      await pumpEventQueue(times: 100);
      expect(bloc.state.showSpWallet, isFalse);
      expect(bloc.state.totalBalance(), 0);
      expect(states.every((s) => !s.showSpWallet), isTrue);
      catalog.complete(const Ok(<Wallet>[]));
      await pumpEventQueue(times: 100);
      await sub.cancel();
      await bloc.close();
    });

    test(
      'WalletStarted invalidates SP balance while reloading wallets',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        final refreshLoaded = Completer<Result<SilentWallet?, WalletFailure>>();

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
        expect(startupState.spBalanceSat, 0);
        expect(startupState.showSpWallet, isFalse);

        refreshLoaded.complete(Ok(_spWallet(9876)));
        await pumpEventQueue(times: 100);
        await sub.cancel();
        await bloc.close();
      },
    );

    test('SilentBalanceChanged requests a guarded snapshot', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      // Every untagged balance notification rechecks setup and admission.
      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(_spWallet(0)));

      final controller = StreamController<SilentUpdate>.broadcast();
      addTearDown(controller.close);

      final bloc = _makeBloc(
        refreshSp: refreshSp,
        checkSetup: checkSetup,
        spUpdates: controller.stream,
      );

      // Let _onStarted run far enough to subscribe to the SP stream and to
      // settle the full-path refreshes it dispatches on startup.
      await drive(bloc, const WalletStarted());

      // Count only the refresh caused by this notification.
      clearInteractions(refreshSp);
      clearInteractions(checkSetup);

      when(() => refreshSp.execute())
          .thenAnswer((_) async => Ok(_spWallet(1234)));
      final balanced = bloc.stream.firstWhere((s) => s.spBalanceSat == 1234);

      controller.add(SilentBalanceChanged(Sats.fromInt(9876)));

      await balanced;
      expect(bloc.state.spBalanceSat, 1234);

      // The accepted amount comes from the guarded facade snapshot.
      verify(() => checkSetup.execute()).called(1);
      verify(() => refreshSp.execute()).called(1);

      await bloc.close();
    });

    test(
      'SilentBalanceChanged includes only the revalidated amount in total',
      () async {
        final refreshSp = _MockRefreshSpWalletForWallet();
        final checkSetup = _MockCheckSpWalletSetupForWallet();
        when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
        when(() => refreshSp.execute())
            .thenAnswer((_) async => Ok(_spWallet(0)));

        final controller = StreamController<SilentUpdate>.broadcast();
        addTearDown(controller.close);

        final bloc = _makeBloc(
          refreshSp: refreshSp,
          checkSetup: checkSetup,
          spUpdates: controller.stream,
        );

        await drive(bloc, const WalletStarted());

        when(() => refreshSp.execute())
            .thenAnswer((_) async => Ok(_spWallet(9876)));
        final balanced = bloc.stream.firstWhere((s) => s.spBalanceSat == 9876);
        controller.add(SilentBalanceChanged(Sats.fromInt(9876)));

        await balanced;
        expect(bloc.state.totalBalance(), 9876);

        await bloc.close();
      },
    );

    test('SilentSetupChanged drives a full re-evaluate', () async {
      final refreshSp = _MockRefreshSpWalletForWallet();
      final checkSetup = _MockCheckSpWalletSetupForWallet();
      final wallet = _spWallet(4321);
      when(() => checkSetup.execute()).thenAnswer((_) async => Ok(true));
      when(() => refreshSp.execute()).thenAnswer((_) async => Ok(wallet));

      final controller = StreamController<SilentUpdate>.broadcast();
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

      controller.add(const SilentSetupChanged());

      await loaded;
      await pumpEventQueue(times: 100);
      expect(bloc.state.isSpWalletSetup, isTrue);
      expect(bloc.state.spBalanceSat, 4321);
      verify(() => checkSetup.execute()).called(1);
      verify(() => refreshSp.execute()).called(1);

      await bloc.close();
    });
  });
}

class _ReadWallet extends Mock implements ReadWalletUsecase {}
