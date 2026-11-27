import 'package:bb_mobile/features/wallet/domain/wallet_failure_log_code.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' show SyncBusyFailure, SyncConnectionFailure;
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sync/sync.dart' show SyncReason;

import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:overview/setup.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:overview/overview.dart';
import 'package:preferences/preferences.dart'
    show
        AmountDisplayPreferences,
        AmountDisplayPreferencesReader,
        PreferencesFailure,
        PreferencesReadFailure;
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, Err, Ok, Result, ScriptType;
import 'package:swaps/swaps.dart'
    show Swap, SwapEnvironment, SwapStatus, SwapType;
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';

import 'dart:async';

import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:network/network.dart'
    show ExternalTorProxyDiagnostic, ExternalTorProxyStatus;
import 'package:swap_feature/swap_feature.dart'
    show SwapActivity, SwapHomeServerCheck;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _ReadWallet extends Mock implements ReadWalletUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockCheckWalletSyncingUsecase extends Mock
    implements CheckWalletSyncingUsecase {}

class _MockWatchWalletSyncEventsUsecase extends Mock
    implements WatchWalletSyncEventsUsecase {}

class _MockSyncWalletsUsecase extends Mock implements SyncWalletsUsecase {}

class _MockOngoingSwaps extends Mock implements OngoingSwaps {}

class _MockExternalTorStatusUsecase extends Mock
    implements ExternalTorProxyDiagnostic {}

class _DisabledSilent extends Fake implements Silent {
  @override
  Future<Result<bool, SilentFailure>> isFeatureEnabled() async =>
      const Ok(false);
  @override
  Future<Result<bool, SilentFailure>> isSetUp() async => const Ok(false);
  @override
  Stream<Result<SilentUpdate, SilentFailure>> watchUpdates() =>
      const Stream.empty();
}

WalletBloc createBloc(
  ExternalTorProxyDiagnostic externalStatus, {
  GetWalletsUsecase? getWallets,
  SyncWalletsUsecase? refreshSync,
  CheckWalletSyncingUsecase? checkSyncing,
  ReadWalletUsecase? readWallet,
  OngoingSwaps? getUnconfirmed,
  OverviewAmountDisplay? amountDisplay,
  SwapActivity? retrySwaps,
  SwapHomeServerCheck? checkSwapServer,
}) {
  return WalletBloc(
    amountDisplay: amountDisplay,
    swapActivity: retrySwaps,
    swapServerCheck: checkSwapServer,
    readWalletUsecase: readWallet ?? _stubbedReadWallet(),
    getWalletsUsecase: getWallets ?? _MockGetWalletsUsecase(),
    checkWalletSyncingUsecase: checkSyncing ?? _MockCheckWalletSyncingUsecase(),
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: refreshSync ?? _stubbedSync(),
    ongoingSwaps: getUnconfirmed ?? _MockOngoingSwaps(),
    readBackupWarning: () async => null,
    externalTorProxy: externalStatus,
    silentHome: SilentHomeObservation(_DisabledSilent()),
  );
}

class _MockSyncWalletUsecase extends Mock implements WalletRepository {}

class _ViewWalletBloc extends Mock implements WalletBloc {}

class _MockSwapActivity extends Mock implements SwapActivity {}

class _MockSwapServerCheck extends Mock implements SwapHomeServerCheck {}

class _AmountReader implements AmountDisplayPreferencesReader {
  final Stream<Result<AmountDisplayPreferences, PreferencesFailure>> stream;

  _AmountReader(this.stream);

  @override
  Stream<Result<AmountDisplayPreferences, PreferencesFailure>>
  watchDisplayPreferences() => stream;
}

void main() {
  test(
    'detail action lifetime retires before a replacement read and on close',
    () async {
      final wallets = _MockGetWalletsUsecase();
      final pending = Completer<Result<List<Wallet>, WalletFailure>>();
      var replacing = false;
      when(() => wallets.execute()).thenAnswer((_) async {
        if (replacing) return pending.future;
        return Ok([_syncedWallet]);
      });
      final checking = _MockCheckWalletSyncingUsecase();
      when(checking.execute).thenReturn(const Ok(false));
      final bloc = createBloc(
        _MockExternalTorStatusUsecase(),
        getWallets: wallets,
        checkSyncing: checking,
      );
      addTearDown(() async {
        if (!pending.isCompleted) pending.complete(Ok([_syncedWallet]));
        if (!bloc.isClosed) await bloc.close();
      });
      bloc.add(const WalletStarted());
      await pumpEventQueue();
      final first = bloc.walletActionsGeneration;
      expect(first, isNotNull);
      replacing = true;
      bloc.add(const WalletStarted());
      await pumpEventQueue();
      expect(bloc.walletActionsGeneration, isNull);
      pending.complete(Ok([_syncedWallet]));
      await pumpEventQueue();
      expect(bloc.walletActionsGeneration, isNotNull);
      expect(bloc.walletActionsGeneration, isNot(first));
      final closing = bloc.close();
      expect(bloc.walletActionsGeneration, isNull);
      await closing;
    },
  );

  test(
    'amount preferences fail closed, recover, and stop on Wallet close',
    () async {
      var cancelled = false;
      final updates =
          StreamController<
            Result<AmountDisplayPreferences, PreferencesFailure>
          >(onCancel: () => cancelled = true);
      addTearDown(updates.close);
      final bloc = createBloc(
        _MockExternalTorStatusUsecase(),
        amountDisplay: OverviewAmountDisplay(_AmountReader(updates.stream)),
      );
      addTearDown(() async {
        if (!bloc.isClosed) await bloc.close();
      });
      const visible = (
        bitcoinUnit: BitcoinUnit.sats,
        hideAmounts: false,
        currencyCode: 'USD',
      );
      expect(bloc.state.amountDisplay, isNull);
      updates.add(const Ok(visible));
      await pumpEventQueue();
      expect(bloc.state.amountDisplay, visible);
      updates.add(const Err(PreferencesReadFailure()));
      await pumpEventQueue();
      expect(bloc.state.amountDisplay, isNull);
      updates.add(const Ok(visible));
      await pumpEventQueue();
      expect(bloc.state.amountDisplay, visible);
      await bloc.close();
      expect(cancelled, isTrue);
      updates.add(const Err(PreferencesReadFailure()));
      await pumpEventQueue();
      expect(bloc.state.amountDisplay, visible);
    },
  );

  test('an unreachable swap server raises the home warning', () async {
    final check = _MockSwapServerCheck();
    var reachable = false;
    when(check.reachable).thenAnswer((_) async => reachable);
    final bloc = createBloc(
      _MockExternalTorStatusUsecase(),
      checkSwapServer: check,
    );
    addTearDown(bloc.close);

    bloc.add(const SwapServerCheckRequested());
    await pumpEventQueue();
    expect(bloc.state.swapServerUnreachable, isTrue);

    reachable = true;
    bloc.add(const SwapServerCheckRequested());
    await pumpEventQueue();
    expect(bloc.state.swapServerUnreachable, isFalse);
  });

  test('a manual refresh retries ongoing swaps at once', () async {
    final retrySwaps = _MockSwapActivity();
    final retryPending = Completer<void>();
    when(retrySwaps.retryOngoingSwaps).thenAnswer((_) => retryPending.future);
    final getWallets = _MockGetWalletsUsecase();
    when(() => getWallets.execute())
        .thenAnswer((_) async => Ok([_syncedWallet]));
    final bloc = createBloc(
      _MockExternalTorStatusUsecase(),
      getWallets: getWallets,
      retrySwaps: retrySwaps,
    );

    addTearDown(bloc.close);
    bloc.add(const WalletRefreshed());
    await pumpEventQueue();
    verifyNever(retrySwaps.retryOngoingSwaps);
    await bloc.refresh();
    await pumpEventQueue();

    verify(retrySwaps.retryOngoingSwaps).called(1);
    expect(retryPending.isCompleted, isFalse);
    retryPending.complete();
  });

  for (final catalogueChanged in [false, true]) {
    test(
      'pass completion preserves incoming unless catalogue changed: $catalogueChanged',
      () async {
        final syncGate = Completer<Result<void, WalletFailure>>();
        final sync = _MockSyncWalletsUsecase();
        when(() => sync.execute(trigger: SyncTrigger.user))
            .thenAnswer((_) => syncGate.future);
        final pending = Completer<Result<List<Swap>, OngoingSwapsFailure>>();
        final balance = _MockOngoingSwaps();
        final wallets = _MockGetWalletsUsecase();
        when(balance.read).thenAnswer((_) => pending.future);
        when(() => wallets.execute()).thenAnswer(
          (_) async => Ok(catalogueChanged ? <Wallet>[] : [_syncedWallet]),
        );
        final bloc = createBloc(
          _MockExternalTorStatusUsecase(),
          getWallets: wallets,
          getUnconfirmed: balance,
          refreshSync: sync,
        );
        addTearDown(bloc.close);
        bloc.emit(
          WalletState(wallets: [_syncedWallet], ongoingSwaps: [_swap('held')]),
        );
        bloc.add(const WalletRefreshed(trigger: SyncTrigger.user));
        await pumpEventQueue();
        expect(bloc.state.isRefreshing, isTrue);
        bloc.add(WalletSyncFinished(_syncedWallet));
        await pumpEventQueue();
        verify(balance.read).called(1);
        syncGate.complete(const Ok(null));
        await pumpEventQueue();
        expect(bloc.state.isRefreshing, isFalse);
        pending.complete(const Ok(<Swap>[]));
        await pumpEventQueue();
        expect(
          bloc.state.ongoingSwaps,
          catalogueChanged ? [_swap('held')] : isEmpty,
        );
      },
    );
  }

  registerFallbackValue(SyncReason.auto);
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'started only sets indicator; finished refreshes its wallet and balance',
    () async {
      final wallets = _MockGetWalletsUsecase();
      final readWallet = _stubbedReadWallet();
      final balance = _MockOngoingSwaps();
      when(() => wallets.execute())
          .thenAnswer((_) async => Ok([_syncedWallet]));
      when(balance.read).thenAnswer((_) async => Ok([_swap('read')]));
      final bloc = createBloc(
        _MockExternalTorStatusUsecase(),
        getWallets: wallets,
        readWallet: readWallet,
        getUnconfirmed: balance,
      );
      addTearDown(bloc.close);
      bloc.emit(WalletState(wallets: [_syncedWallet]));
      final started = bloc.stream.firstWhere(
        (s) => s.syncStatus[_syncedWallet.id] == true,
      );
      bloc.add(WalletSyncStarted(_syncedWallet.id));
      await started;
      verifyZeroInteractions(wallets);
      verifyZeroInteractions(balance);
      expect(bloc.state.wallets, [_syncedWallet]);
      final finished = bloc.stream.firstWhere(
        (s) => s.syncStatus[_syncedWallet.id] == false,
      );
      bloc.add(WalletSyncFinished(_syncedWallet));
      await finished;
      await pumpEventQueue();
      expect(bloc.state.wallets, [_syncedWallet]);
      expect(bloc.state.ongoingSwaps, [_swap('read')]);
      verifyNever(() => wallets.execute());
      verify(() => readWallet.execute(_syncedWallet.id)).called(1);
      verify(balance.read).called(1);
    },
  );

  test('finishing A never admits a reader for B', () async {
    final read = _stubbedReadWallet();
    final wallets = _MockGetWalletsUsecase();
    final balance = _MockOngoingSwaps();
    final other = _syncedWallet.copyWith(
      origin: 'other',
      balanceSat: BigInt.from(7),
    );
    when(() => wallets.execute())
        .thenAnswer((_) async => Ok([_syncedWallet, other]));
    when(balance.read).thenAnswer((_) async => Ok([_swap('read')]));
    final bloc = createBloc(
      _MockExternalTorStatusUsecase(),
      getWallets: wallets,
      readWallet: read,
      getUnconfirmed: balance,
    );
    addTearDown(bloc.close);
    bloc.emit(
      WalletState(
        wallets: [other, _syncedWallet],
        syncStatus: {other.id: true, _syncedWallet.id: true},
      ),
    );
    bloc.add(WalletSyncFinished(_syncedWallet));
    await pumpEventQueue();
    verifyNever(() => wallets.execute());
    verify(() => read.execute(_syncedWallet.id)).called(1);
    verifyNever(() => read.execute(other.id));
    expect(bloc.state.wallets.map((w) => w.id), [other.id, _syncedWallet.id]);
    expect(bloc.state.wallets.first, same(other));
    expect(bloc.state.syncStatus, {other.id: true, _syncedWallet.id: false});
  });

  test(
    'a failed swap read keeps the notices; a confirmed empty read clears them',
    () async {
      final swaps = _MockOngoingSwaps();
      var failed = true;
      when(swaps.read).thenAnswer(
        (_) async =>
            failed ? const Err(OngoingSwapsUnavailableFailure()) : const Ok([]),
      );
      final bloc = createBloc(
        _MockExternalTorStatusUsecase(),
        getUnconfirmed: swaps,
      );
      addTearDown(bloc.close);
      final held = _swap('held');
      bloc.emit(WalletState(wallets: [_syncedWallet], ongoingSwaps: [held]));
      bloc.add(WalletSyncFinished(_syncedWallet));
      await pumpEventQueue();
      verify(swaps.read).called(1);
      expect(bloc.state.ongoingSwaps, [held]);
      failed = false;
      bloc.add(WalletSyncFinished(_syncedWallet));
      await pumpEventQueue();
      verify(swaps.read).called(1);
      expect(bloc.state.ongoingSwaps, isEmpty);
    },
  );

  test('revisions of different wallets both land without reordering', () async {
    final other = _syncedWallet.copyWith(
      origin: 'other',
      balanceSat: BigInt.from(7),
    );
    final updated = _syncedWallet.copyWith(balanceSat: BigInt.from(11));
    final updatedOther = other.copyWith(balanceSat: BigInt.from(13));
    final a = Completer<Result<Wallet, WalletFailure>>();
    final b = Completer<Result<Wallet, WalletFailure>>();
    final read = _ReadWallet();
    when(() => read.execute(_syncedWallet.id)).thenAnswer((_) => a.future);
    when(() => read.execute(other.id)).thenAnswer((_) => b.future);
    final wallets = _MockGetWalletsUsecase();
    final bloc = createBloc(
      _MockExternalTorStatusUsecase(),
      getWallets: wallets,
      readWallet: read,
    );
    addTearDown(bloc.close);
    bloc.emit(
      WalletState(
        wallets: [other, _syncedWallet],
        syncStatus: {other.id: true},
      ),
    );
    bloc.add(WalletRevisionChanged(_syncedWallet.id));
    bloc.add(WalletRevisionChanged(other.id));
    await pumpEventQueue();
    b.complete(Ok(updatedOther));
    await pumpEventQueue();
    a.complete(Ok(updated));
    await pumpEventQueue();
    expect(bloc.state.wallets, [updatedOther, updated]);
    expect(bloc.state.totalBalance(), 24);
    expect(bloc.state.syncStatus, {other.id: true});
    verifyZeroInteractions(wallets);
  });

  test(
    'older revisions cannot overwrite newer ones; unknown ids are ignored',
    () async {
      final first = Completer<Result<Wallet, WalletFailure>>();
      final second = Completer<Result<Wallet, WalletFailure>>();
      final read = _ReadWallet();
      var count = 0;
      when(() => read.execute(_syncedWallet.id))
          .thenAnswer((_) => count++ == 0 ? first.future : second.future);
      final bloc = createBloc(
        _MockExternalTorStatusUsecase(),
        readWallet: read,
      );
      addTearDown(bloc.close);
      bloc.emit(WalletState(wallets: [_syncedWallet]));
      bloc.add(WalletRevisionChanged(_syncedWallet.id));
      await pumpEventQueue();
      bloc.add(WalletRevisionChanged(_syncedWallet.id));
      await pumpEventQueue();
      final updated = _syncedWallet.copyWith(balanceSat: BigInt.from(11));
      second.complete(Ok(updated));
      await pumpEventQueue();
      first.complete(Ok(_syncedWallet));
      await pumpEventQueue();
      expect(bloc.state.wallets, [updated]);
      bloc.emit(const WalletState());
      bloc.add(WalletRevisionChanged('unknown'));
      await pumpEventQueue();
      expect(bloc.state.wallets, isEmpty);
      verifyNever(() => read.execute('unknown'));
    },
  );

  test(
    'removing a wallet while its revision read is pending never resurrects it',
    () async {
      final pending = Completer<Result<Wallet, WalletFailure>>();
      final read = _ReadWallet();
      when(() => read.execute(_syncedWallet.id))
          .thenAnswer((_) => pending.future);
      final bloc = createBloc(
        _MockExternalTorStatusUsecase(),
        readWallet: read,
      );
      addTearDown(bloc.close);
      bloc.emit(WalletState(wallets: [_syncedWallet]));
      bloc.add(WalletRevisionChanged(_syncedWallet.id));
      await pumpEventQueue();
      bloc.emit(const WalletState());
      pending.complete(Ok(_syncedWallet));
      await pumpEventQueue();
      expect(bloc.state.wallets, isEmpty);
    },
  );

  for (final targetedFinishesFirst in [true, false]) {
    test(
      'full refresh preserves a newer targeted balance (targeted first: $targetedFinishesFirst)',
      () async {
        final pending = Completer<Result<List<Wallet>, WalletFailure>>();
        final wallets = _MockGetWalletsUsecase();
        when(() => wallets.execute()).thenAnswer((_) => pending.future);
        final targeted = Completer<Result<Wallet, WalletFailure>>();
        final read = _ReadWallet();
        final updated = _syncedWallet.copyWith(balanceSat: BigInt.from(19));
        when(() => read.execute(_syncedWallet.id))
            .thenAnswer((_) => targeted.future);
        final bloc = createBloc(
          _MockExternalTorStatusUsecase(),
          getWallets: wallets,
          readWallet: read,
        );
        addTearDown(bloc.close);
        bloc.emit(WalletState(wallets: [_syncedWallet]));
        bloc.add(const WalletRefreshed());
        await pumpEventQueue();
        bloc.add(WalletRevisionChanged(_syncedWallet.id));
        await pumpEventQueue();
        if (targetedFinishesFirst) {
          targeted.complete(Ok(updated));
          await pumpEventQueue();
        }
        pending.complete(Ok([_syncedWallet]));
        await pumpEventQueue();
        if (!targetedFinishesFirst) {
          targeted.complete(Ok(updated));
          await pumpEventQueue();
        }
        expect(bloc.state.wallets, [updated]);
        expect(bloc.state.isRefreshing, isFalse);
      },
    );
  }

  test(
    'older incoming balance reads cannot overwrite newer finishes',
    () async {
      final first = Completer<Result<List<Swap>, OngoingSwapsFailure>>();
      final second = Completer<Result<List<Swap>, OngoingSwapsFailure>>();
      final balance = _MockOngoingSwaps();
      var count = 0;
      when(balance.read)
          .thenAnswer((_) => count++ == 0 ? first.future : second.future);
      final bloc = createBloc(
        _MockExternalTorStatusUsecase(),
        getUnconfirmed: balance,
      );
      addTearDown(bloc.close);
      bloc.emit(WalletState(wallets: [_syncedWallet]));
      bloc.add(WalletSyncFinished(_syncedWallet));
      await pumpEventQueue();
      bloc.add(WalletSyncFinished(_syncedWallet));
      await pumpEventQueue();
      second.complete(Ok([_swap('second')]));
      await pumpEventQueue();
      first.complete(Ok([_swap('first')]));
      await pumpEventQueue();
      expect(bloc.state.ongoingSwaps, [_swap('second')]);
    },
  );

  for (final trigger in [SyncTrigger.automatic, SyncTrigger.user]) {
    testWidgets('$trigger busy does not render a generic failure card', (
      tester,
    ) async {
      late WalletState settled;
      await tester.runAsync(() async {
        final dir = Directory.systemTemp.createTempSync('review-fix2-busy-');
        log = Logger.replace(directory: dir);
        final getWallets = _MockGetWalletsUsecase();
        when(() => getWallets.execute())
            .thenAnswer((_) async => Ok([_syncedWallet]));
        when(() => getWallets.execute(onlyBitcoin: true))
            .thenAnswer((_) async => Ok([_syncedWallet]));
        when(() => getWallets.execute(onlyLiquid: true))
            .thenAnswer((_) async => const Ok(<Wallet>[]));
        final single = _MockSyncWalletUsecase();
        when(
          () => single.sync(
            _syncedWallet,
            discover: any(named: 'discover'),
            reason: any(named: 'reason'),
          ),
        ).thenThrow(const WalletSnapshotException(SyncBusyFailure()));
        final coordinator = SyncCoordinator<Wallet, WalletFailure>(
          walletKey: (wallet) =>
              WalletKey(id: wallet.id, network: wallet.network.shared),
          classifyFailure: (failure) =>
              (empty: failure is NoWalletsFoundFailure, code: failure.logCode),
          getWallets: ({onlyBitcoin, onlyLiquid}) async =>
              (await getWallets.execute(
                onlyBitcoin: onlyBitcoin,
                onlyLiquid: onlyLiquid,
              )).map((wallets) => WalletRead<Wallet, WalletFailure>(wallets)),
          syncWallet: single.sync,
        );
        final bloc = WalletBloc(
          readWalletUsecase: _stubbedReadWallet(),
          getWalletsUsecase: getWallets,
          checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
          watchWalletSyncEventsUsecase: _stubbedWatchers(),
          syncWalletsUsecase: SyncWalletsUsecase(coordinator.sync),
          ongoingSwaps: _MockOngoingSwaps(),
          silentHome: SilentHomeObservation(_DisabledSilent()),
          readBackupWarning: () async => null,
          externalTorProxy: _MockExternalTorStatusUsecase(),
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
      when(() => viewBloc.stream)
          .thenAnswer((_) => const Stream<WalletState>.empty());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
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
    when(() => sync.execute(trigger: SyncTrigger.automatic))
        .thenAnswer((_) => gate.future);
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
      when(() => getWallets.execute())
          .thenAnswer((_) async => Ok([_syncedWallet]));
      when(() => getWallets.execute(onlyBitcoin: true))
          .thenAnswer((_) async => Ok([_syncedWallet]));
      when(() => getWallets.execute(onlyLiquid: true))
          .thenAnswer((_) async => const Err(NoWalletsFoundFailure()));
      final single = _MockSyncWalletUsecase();
      var nativePasses = 0;
      final syncGate = Completer<void>();
      when(
        () => single.sync(
          _syncedWallet,
          discover: any(named: 'discover'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {
        nativePasses++;
        await syncGate.future;
        throw const WalletSnapshotException(SyncConnectionFailure());
      });
      final coordinator = SyncCoordinator<Wallet, WalletFailure>(
        walletKey: (wallet) =>
            WalletKey(id: wallet.id, network: wallet.network.shared),
        classifyFailure: (failure) =>
            (empty: failure is NoWalletsFoundFailure, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async =>
            (await getWallets.execute(
              onlyBitcoin: onlyBitcoin,
              onlyLiquid: onlyLiquid,
            )).map((wallets) => WalletRead<Wallet, WalletFailure>(wallets)),
        syncWallet: single.sync,
      );
      final bloc = WalletBloc(
        readWalletUsecase: _stubbedReadWallet(),
        getWalletsUsecase: getWallets,
        checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
        watchWalletSyncEventsUsecase: _stubbedWatchers(),
        syncWalletsUsecase: SyncWalletsUsecase(coordinator.sync),
        ongoingSwaps: _MockOngoingSwaps(),
        silentHome: SilentHomeObservation(_DisabledSilent()),
        readBackupWarning: () async => null,
        externalTorProxy: _MockExternalTorStatusUsecase(),
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
          reason: 'The native boundary owns the failed pass; waiters must not repeat it.',
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
      'unreadable Bitcoin proxy keeps the Tor settings destination',
      ExternalTorProxyStatus.unreadable,
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
      when(status.check).thenAnswer((_) async => scenario.$2);
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
      verifyNever(status.check);
    },
  );

  test(
    'a newer success clears a warning after an older proxy check completes',
    () async {
      final status = _MockExternalTorStatusUsecase();
      final started = Completer<void>();
      final release = Completer<ExternalTorProxyStatus>();
      when(status.check).thenAnswer((_) async {
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

  test('a failed wallet load is reported, not shown as an empty wallet', () async {
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
  });

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

  test(
    'a reload after a recovery never reports the previous "no wallets"',
    () async {
      // The home screen routes to onboarding while "no wallets" is reported.
      // After a recovery it opens while the reload is still reading, so a
      // stale answer sent it back to onboarding mid-transition.
      final getWallets = _MockGetWalletsUsecase();
      final reload = Completer<Result<List<Wallet>, WalletFailure>>();
      var reads = 0;
      when(
        () => getWallets.execute(
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
          onlyLiquid: any(named: 'onlyLiquid'),
          sync: any(named: 'sync'),
        ),
      ).thenAnswer(
        (_) => ++reads == 1
            ? Future.value(const Err(NoWalletsFoundFailure()))
            : reload.future,
      );
      final syncing = _MockCheckWalletSyncingUsecase();
      when(() => syncing.execute(walletId: any(named: 'walletId')))
          .thenReturn(const Ok<bool, WalletFailure>(false));
      final bloc = WalletBloc(
        readWalletUsecase: _stubbedReadWallet(),
        getWalletsUsecase: getWallets,
        checkWalletSyncingUsecase: syncing,
        watchWalletSyncEventsUsecase: _stubbedWatchers(),
        syncWalletsUsecase: _stubbedSync(),
        ongoingSwaps: _MockOngoingSwaps(),
        silentHome: SilentHomeObservation(_DisabledSilent()),
        readBackupWarning: () async => null,
        externalTorProxy: _MockExternalTorStatusUsecase(),
      );
      addTearDown(bloc.close);

      bloc.add(const WalletStarted());
      await pumpEventQueue();
      expect(bloc.state.noWalletsFound, isTrue);

      final observed = <WalletState>[];
      final subscription = bloc.stream.listen(observed.add);
      addTearDown(subscription.cancel);
      bloc.add(const WalletStarted());
      await pumpEventQueue();

      expect(reads, 2, reason: 'the reload is still reading');
      expect(bloc.state.noWalletsFound, isFalse);

      reload.complete(Ok([_syncedWallet]));
      await pumpEventQueue();

      expect(bloc.state.wallets, [_syncedWallet]);
      expect(observed.where((state) => state.noWalletsFound), isEmpty);
    },
  );

  test('a reload that finds no wallets still routes to onboarding', () async {
    final bloc = _blocWithFailingLoad(const NoWalletsFoundFailure());
    addTearDown(bloc.close);

    bloc.add(const WalletStarted());
    await pumpEventQueue();
    bloc.add(const WalletStarted());
    await pumpEventQueue();

    expect(bloc.state.noWalletsFound, isTrue);
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
    readWalletUsecase: _stubbedReadWallet(),
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: _MockCheckWalletSyncingUsecase(),
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: sync ?? _stubbedSync(),
    ongoingSwaps: _MockOngoingSwaps(),
    silentHome: SilentHomeObservation(_DisabledSilent()),
    readBackupWarning: () async => null,
    externalTorProxy: _MockExternalTorStatusUsecase(),
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
  when(() => sync.execute(trigger: any(named: 'trigger')))
      .thenAnswer((_) async => const Ok<void, WalletFailure>(null));
  return sync;
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
  when(() => sync.execute(trigger: any(named: 'trigger')))
      .thenAnswer((_) async => Err<void, WalletFailure>(failure));

  final syncing = _MockCheckWalletSyncingUsecase();
  when(() => syncing.execute(walletId: any(named: 'walletId')))
      .thenReturn(const Ok<bool, WalletFailure>(false));

  return WalletBloc(
    readWalletUsecase: _stubbedReadWallet(),
    getWalletsUsecase: getWallets,
    checkWalletSyncingUsecase: syncing,
    watchWalletSyncEventsUsecase: _stubbedWatchers(),
    syncWalletsUsecase: sync,
    ongoingSwaps: _MockOngoingSwaps(),
    silentHome: SilentHomeObservation(_DisabledSilent()),
    readBackupWarning: () async => null,
    externalTorProxy: _MockExternalTorStatusUsecase(),
  );
}

ReadWalletUsecase _stubbedReadWallet() {
  final read = _ReadWallet();
  when(() => read.execute(any())).thenAnswer((_) async => Ok(_syncedWallet));
  return read;
}

Swap _swap(String id) => Swap.chain(
  id: id,
  keyIndex: 0,
  type: SwapType.bitcoinToLiquid,
  status: SwapStatus.paid,
  environment: SwapEnvironment.mainnet,
  creationTime: DateTime.utc(2026),
  sendWalletId: 'w1',
  paymentAddress: 'bc1qexampleaddress',
  paymentAmount: 1000,
  sendTxid: 'lockup',
);
