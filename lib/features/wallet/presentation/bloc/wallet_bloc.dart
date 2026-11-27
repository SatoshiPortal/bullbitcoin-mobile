import 'package:preferences/preferences.dart' show AmountDisplayPreferences;
import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure_log_code.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_revisions_usecase.dart';

import 'dart:async';

import 'package:silent/silent.dart' show SilentHomeObservation;
import 'package:electrum/electrum.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:network/network.dart'
    show ExternalTorProxyDiagnostic, ExternalTorProxyStatus;
import 'package:swap_feature/swap_feature.dart'
    show SwapActivity, SwapHomeServerCheck;
import 'package:swaps/swaps.dart' show Swap;
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_bloc.freezed.dart';
part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    OverviewAmountDisplay? amountDisplay,
    WatchWalletRevisionsUsecase? watchWalletRevisionsUsecase,
    this._swapActivity,
    this._swapServerCheck,
    required this._getWalletsUsecase,
    required this._readWalletUsecase,
    required this._checkWalletSyncingUsecase,
    required this._watchWalletSyncEventsUsecase,
    required this._syncWalletsUsecase,
    required this._ongoingSwaps,
    required this._readBackupWarning,
    required ExternalTorProxyDiagnostic externalTorProxy,
    required this._silentHome,
  }) : _homeNetworkWarnings = HomeNetworkWarnings(() async {
         final status = await externalTorProxy.check();
         return status == ExternalTorProxyStatus.unavailable ||
             status == ExternalTorProxyStatus.unreadable;
       }),
       super(const WalletState()) {
    on<_WalletAmountDisplayChanged>((event, emit) {
      emit(state.copyWith(amountDisplay: event.preferences));
    });
    _amountDisplaySubscription = amountDisplay?.watch().listen((preferences) {
      if (!isClosed) add(_WalletAmountDisplayChanged(preferences));
    });
    _revisionsSubscription = watchWalletRevisionsUsecase?.execute().listen((
      walletId,
    ) {
      if (!isClosed) add(WalletRevisionChanged(walletId));
    });
    on<WalletRevisionChanged>(_onRevisionChanged);
    on<WalletStarted>(_onStarted, transformer: restartable());
    on<SwapServerCheckRequested>(
      _onSwapServerCheckRequested,
      transformer: droppable(),
    );
    on<WalletRefreshed>(_onRefreshed, transformer: droppable());
    on<WalletSyncStarted>(_onWalletSyncStarted);
    on<WalletSyncFinished>(_onWalletSyncFinished);
    on<ElectrumSyncResultChanged>(_onElectrumSyncResultChanged);
    on<RefreshSpWallet>(_onRefreshSpWallet, transformer: restartable());
    on<SetSpWalletBalance>(_onSetSpWalletBalance);
    on<DismissBackupWarning>(_onDismissBackupWarning);
    on<VerifyBackupStatus>(_onVerifyBackupStatus);
  }

  late final StreamSubscription<AmountDisplayPreferences?>?
  _amountDisplaySubscription;
  final GetWalletsUsecase _getWalletsUsecase;
  final ReadWalletUsecase _readWalletUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;
  final WatchWalletSyncEventsUsecase _watchWalletSyncEventsUsecase;
  final SyncWalletsUsecase _syncWalletsUsecase;
  final SwapActivity? _swapActivity;
  final OngoingSwaps _ongoingSwaps;
  final SwapHomeServerCheck? _swapServerCheck;
  final Future<bool?> Function() _readBackupWarning;
  final HomeNetworkWarnings _homeNetworkWarnings;
  final SilentHomeObservation _silentHome;

  StreamSubscription? _revisionsSubscription;
  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;
  StreamSubscription? _electrumSyncResultsSubscription;

  int _catalogGeneration = 0;
  int _walletActionsEpoch = 0;
  bool _walletActionsAdmitted = false;
  final _walletActionChanges = StreamController<void>.broadcast();
  bool _closing = false;
  int _ongoingSwapsReadVersion = 0;
  final Map<String, int> _walletUpdateVersions = {};
  final Map<String, int> _walletReadVersions = {};

  int _backupStatusGeneration = 0;

  /// Lifetime of the legacy catalogue used by the detail action adapter.
  /// This does not authorize a Secrets or Sync operation.
  int? get walletActionsGeneration =>
      _walletActionsAdmitted && !_closing ? _walletActionsEpoch : null;

  Stream<void> get walletActionChanges => _walletActionChanges.stream;

  void _retireWalletActions() {
    if (_closing) return;
    _walletActionsEpoch++;
    _walletActionsAdmitted = false;
    _walletActionChanges.add(null);
  }

  void _admitWalletActions() {
    if (_closing || _walletActionsAdmitted) return;
    _walletActionsAdmitted = true;
    _walletActionChanges.add(null);
  }

  @override
  Future<void> close() async {
    _closing = true;
    _homeNetworkWarnings.close();
    unawaited(_walletActionChanges.close());
    final amountDisplayClosed = _amountDisplaySubscription?.cancel();
    await _silentHome.close();
    await amountDisplayClosed;
    _revisionsSubscription?.cancel();
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
    _electrumSyncResultsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onRevisionChanged(
    WalletRevisionChanged event,
    Emitter<WalletState> emit,
  ) async {
    await _reloadWallet(event.walletId, emit);
  }

  Future<void> _reloadWallet(String walletId, Emitter<WalletState> emit) async {
    // A revision is not a catalogue event: never insert an unknown wallet or
    // resurrect one deleted while its native read was in flight.
    if (!state.wallets.any((wallet) => wallet.id == walletId)) return;
    final catalog = _catalogGeneration;
    final version = (_walletReadVersions[walletId] ?? 0) + 1;
    _walletReadVersions[walletId] = version;
    final result = await _readWalletUsecase.execute(walletId);
    if (emit.isDone ||
        catalog != _catalogGeneration ||
        _walletReadVersions[walletId] != version) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        _walletUpdateVersions[walletId] =
            (_walletUpdateVersions[walletId] ?? 0) + 1;
        emit(
          state.copyWith(
            wallets: [
              for (final wallet in state.wallets)
                if (wallet.id == walletId) value else wallet,
            ],
          ),
        );
      case Err(:final failure):
        log.warning(
          'Wallet revision read unavailable category=${failure.logCode}',
        );
    }
  }

  List<Wallet> _mergeWalletUpdates(
    List<Wallet> loaded,
    Map<String, int> before,
  ) {
    final current = {for (final wallet in state.wallets) wallet.id: wallet};
    return [
      for (final wallet in loaded)
        if (_walletUpdateVersions[wallet.id] != before[wallet.id])
          current[wallet.id] ?? wallet
        else
          wallet,
    ];
  }

  Future<void> _onStarted(
    WalletStarted event,
    Emitter<WalletState> emit,
  ) async {
    add(const SwapServerCheckRequested());
    final catalog = ++_catalogGeneration;
    _retireWalletActions();
    _silentHome.catalogReplacing();
    final updates = Map<String, int>.of(_walletUpdateVersions);
    emit(
      state.copyWith(
        isSpFeatureEnabled: false,
        spBalanceSat: 0,
        isSpWalletLoading: false,
        // A stale "no wallets" would send the home screen to onboarding.
        failure: state.noWalletsFound ? null : state.failure,
      ),
    );
    _silentHome.observe(() {
      if (!isClosed) add(const RefreshSpWallet());
    });

    final List<Wallet> wallets;
    final result = await _getWalletsUsecase.execute();
    if (emit.isDone || catalog != _catalogGeneration) return;
    switch (result) {
      case Ok(:final value):
        wallets = value;
      case Err(:final failure):
        emit(state.copyWith(status: WalletStatus.failure, failure: failure));
        return;
    }

    // Both reads below only decorate the list, so each falls back to its safe
    // default rather than discarding wallets the user can already be shown.
    final isSyncing = switch (_checkWalletSyncingUsecase.execute()) {
      Ok(:final value) => value,
      Err() => false,
    };

    _catalogGeneration++;
    _walletReadVersions.clear();
    // Invalidate every SP read tied to the previous catalogue before exposing
    // wallets from the new environment.
    _silentHome.catalogPublished({
      for (final wallet in wallets) wallet.network.environment,
    });
    _backupStatusGeneration++;
    _admitWalletActions();
    emit(
      state.copyWith(
        status: WalletStatus.success,
        isSpFeatureEnabled: false,
        spBalanceSat: 0,
        isSpWalletLoading: false,
        wallets: _mergeWalletUpdates(wallets, updates),
        backupNeeded: null,
        failure: null,
        // If a global sync is running, every wallet is syncing.
        syncStatus: {for (final wallet in wallets) wallet.id: isSyncing},
      ),
    );

    add(const RefreshSpWallet());
    add(const VerifyBackupStatus());

    // Now that the wallets are loaded, we can sync them as done by the refresh
    add(const WalletRefreshed());

    // Now subscribe to syncs starts and finishes to update the UI with the
    // syncing indicator. A dead watcher degrades the screen to its last loaded
    // state, so its failure is logged rather than shown.
    await _startedSyncsSubscription?.cancel();
    await _finishedSyncsSubscription?.cancel();
    await _electrumSyncResultsSubscription?.cancel();
    _startedSyncsSubscription = _watchWalletSyncEventsUsecase.started().listen((
      result,
    ) {
      switch (result) {
        case Ok(:final value):
          add(WalletSyncStarted(value));
        case Err(:final failure):
          log.warning('Wallet sync-started watcher: ${failure.logMessage}');
      }
    });
    _finishedSyncsSubscription = _watchWalletSyncEventsUsecase
        .finished()
        .listen((result) {
          switch (result) {
            case Ok(:final value):
              add(WalletSyncFinished(value));
            case Err(:final failure):
              log.warning(
                'Wallet sync-finished watcher: ${failure.logMessage}',
              );
          }
        });
    _electrumSyncResultsSubscription = _watchWalletSyncEventsUsecase
        .electrumResults()
        .listen((result) {
          switch (result) {
            case Ok(:final value):
              add(ElectrumSyncResultChanged(value));
            case Err(:final failure):
              log.warning('Electrum results watcher: ${failure.logMessage}');
          }
        });
  }

  /// Wait for the foreground refresh already represented by the UI state.
  /// Unlike [refresh], this never dispatches an event or requests a sync.
  Future<void> waitForRefresh() async {
    if (!state.isRefreshing || isClosed) return;
    await stream.firstWhere(
      (state) => !state.isRefreshing,
      orElse: () => state,
    );
  }

  /// Pull-to-refresh entry point for the UI. Dispatches a user-triggered
  /// refresh (so the data reload and `isRefreshing` transitions still happen)
  /// and awaits the [SyncCoordinator] directly, so the returned future (and
  /// therefore the RefreshIndicator spinner) resolves only once bitcoin and
  /// liquid have both synced, rather than tracking the shared
  /// `isRefreshing` flag (which a throttled background refresh can clear after
  /// bitcoin alone). Awaiting the coordinator also bypasses the `droppable()`
  /// event lane, so the gesture is never swallowed by an in-flight background
  /// refresh.
  ///
  /// Never throws: a failed sync is already surfaced through [WalletState] by
  /// [_onRefreshed] and logged (sanitized) by the coordinator, and a
  /// RefreshIndicator callback must not complete with an error.
  Future<void> refresh() async {
    add(const WalletRefreshed(trigger: SyncTrigger.user));
    unawaited(_swapActivity?.retryOngoingSwaps());
    // The result is dropped here because the event dispatched above runs the
    // same sync and puts its failure into WalletState; this await exists only
    // to hold the RefreshIndicator spinner, and its callback must not complete
    // with an error.
    final _ = await _syncWalletsUsecase.execute(trigger: SyncTrigger.user);
  }

  Future<void> _onSwapServerCheckRequested(
    SwapServerCheckRequested event,
    Emitter<WalletState> emit,
  ) async {
    final check = _swapServerCheck;
    if (check == null) return;
    final reachable = await check.reachable();
    if (emit.isDone) return;
    emit(state.copyWith(swapServerUnreachable: !reachable));
  }

  Future<void> _onRefreshed(
    WalletRefreshed event,
    Emitter<WalletState> emit,
  ) async {
    final catalog = _catalogGeneration;
    emit(state.copyWith(isRefreshing: true));
    add(const SwapServerCheckRequested());

    // The sync schedules bitcoin → liquid → swaps → sp sequentially with per-kind dedup,
    // throttling, and a lifecycle gate. A user-triggered refresh
    // (pull-to-refresh) bypasses the throttle; route-driven navigation
    // triggers use SyncTrigger.automatic.
    //
    // A failed round is not fatal: the wallets are re-read below either way,
    // so the list stays correct and only the balances are stale. It is still
    // reported — a refresh that silently did nothing reads as a frozen screen.
    WalletFailure? syncFailure;
    if (await _syncWalletsUsecase.execute(trigger: event.trigger) case Err(
      :final failure,
    )) {
      if (failure is! WalletSyncBusyFailure) syncFailure = failure;
    }

    if (emit.isDone) return;
    if (catalog != _catalogGeneration) {
      emit(state.copyWith(isRefreshing: false));
      return;
    }
    final updates = Map<String, int>.of(_walletUpdateVersions);
    final List<Wallet> wallets;
    final result = await _getWalletsUsecase.execute();
    if (emit.isDone) return;
    if (catalog != _catalogGeneration) {
      emit(state.copyWith(isRefreshing: false));
      return;
    }
    switch (result) {
      case Ok(:final value):
        wallets = value;
      case Err(:final failure):
        _retireWalletActions();
        emit(
          state.copyWith(
            status: WalletStatus.failure,
            failure: failure,
            isRefreshing: false,
          ),
        );
        return;
    }

    // Ordinary rereads must not invalidate a fresh incoming aggregate.
    // A changed catalogue still makes reads from the old membership obsolete.
    final previousKeys = {
      for (final wallet in state.wallets) (wallet.id, wallet.network),
    };
    final loadedKeys = {
      for (final wallet in wallets) (wallet.id, wallet.network),
    };
    if (previousKeys.length != loadedKeys.length ||
        !previousKeys.containsAll(loadedKeys)) {
      _catalogGeneration++;
      _retireWalletActions();
      _silentHome.catalogReplacing();
      _walletReadVersions.clear();
      emit(
        state.copyWith(
          isSpFeatureEnabled: false,
          spBalanceSat: 0,
          isSpWalletLoading: false,
        ),
      );
    }

    _silentHome.catalogPublished({
      for (final wallet in wallets) wallet.network.environment,
    });
    add(const RefreshSpWallet());

    _backupStatusGeneration++;
    _admitWalletActions();
    emit(
      state.copyWith(
        status: WalletStatus.success,
        wallets: _mergeWalletUpdates(wallets, updates),
        backupNeeded: null,
        // Carries the sync failure, or clears a previous one. The wallets
        // themselves loaded, so this is a stale-balance warning on top of a
        // correct list, not a failed load.
        failure: syncFailure,
        syncStatus: {for (final wallet in wallets) wallet.id: false},
        isRefreshing: false,
      ),
    );
    add(const VerifyBackupStatus());
  }

  void _onWalletSyncStarted(
    WalletSyncStarted event,
    Emitter<WalletState> emit,
  ) {
    final syncStatus = Map<String, bool>.from(state.syncStatus);
    syncStatus[event.walletId] = true;
    emit(state.copyWith(syncStatus: syncStatus));
  }

  Future<void> _onWalletSyncFinished(
    WalletSyncFinished event,
    Emitter<WalletState> emit,
  ) async {
    // Clear only this indicator even if its read is unavailable. A partial
    // success cannot clear a failed full-list load or the refresh failure.
    _backupStatusGeneration++;
    emit(
      state.copyWith(
        syncStatus: {...state.syncStatus, event.wallet.id: false},
        backupNeeded: null,
      ),
    );
    add(const VerifyBackupStatus());
    final catalog = _catalogGeneration;
    final ongoingVersion = ++_ongoingSwapsReadVersion;
    await _reloadWallet(event.wallet.id, emit);
    if (emit.isDone || catalog != _catalogGeneration || state.wallets.isEmpty) {
      return;
    }

    // This reads the swap database, never another native wallet.
    final ongoing = await _ongoingSwaps.read();
    if (emit.isDone ||
        catalog != _catalogGeneration ||
        ongoingVersion != _ongoingSwapsReadVersion) {
      return;
    }
    if (ongoing case Ok(:final value)) {
      emit(state.copyWith(ongoingSwaps: value));
    }
  }

  Future<void> _onElectrumSyncResultChanged(
    ElectrumSyncResultChanged event,
    Emitter<WalletState> emit,
  ) async {
    final result = event.result;
    final warnings = await _homeNetworkWarnings.update(
      isLiquid: result.isLiquid,
      success: result.success,
    );
    if (warnings != null && !emit.isDone) {
      emit(state.copyWith(warnings: warnings));
    }
  }

  Future<void> _onRefreshSpWallet(
    RefreshSpWallet event,
    Emitter<WalletState> emit,
  ) => _silentHome.refresh((update) {
    if (emit.isDone) return;
    emit(
      state.copyWith(
        isSpFeatureEnabled: update.visible ?? state.isSpFeatureEnabled,
        isSpWalletSetup: update.configured ?? state.isSpWalletSetup,
        spBalanceSat: update.balanceSat ?? state.spBalanceSat,
        isSpWalletLoading: update.loading,
      ),
    );
  });

  void _onSetSpWalletBalance(
    SetSpWalletBalance event,
    Emitter<WalletState> emit,
  ) {
    // This legacy event has no network provenance. Its amount cannot authorize
    // a cached balance; read a snapshot through the network gate instead.
    add(const RefreshSpWallet());
  }

  void _onDismissBackupWarning(
    DismissBackupWarning event,
    Emitter<WalletState> emit,
  ) {
    emit(state.copyWith(backupWarningDismissed: true));
  }

  Future<void> _onVerifyBackupStatus(
    VerifyBackupStatus event,
    Emitter<WalletState> emit,
  ) async {
    final generation = ++_backupStatusGeneration;
    final needed = await _readBackupWarning();
    if (generation != _backupStatusGeneration || emit.isDone) return;
    if (needed == null) log.warning('recoverbull.backup.status.unavailable');
    emit(state.copyWith(backupNeeded: needed));
  }
}
