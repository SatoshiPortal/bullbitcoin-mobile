import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure_log_code.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'dart:async';

import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_unconfirmed_incoming_balance_usecase.dart';
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
    WatchWalletRevisionsUsecase? watchWalletRevisionsUsecase,
    required this._getWalletsUsecase,
    required this._readWalletUsecase,
    required this._checkWalletSyncingUsecase,
    required this._watchWalletSyncEventsUsecase,
    required this._syncWalletsUsecase,
    required this._getUnconfirmedIncomingBalanceUsecase,
    required this._deleteWalletUsecase,
    required this._checkBackupNeededUsecase,
    required this._getExternalTorProxyStatusUsecase,
    required this._checkSpWalletSetupForWalletUsecase,
    required this._checkSpScanningForWalletUsecase,
    required this._refreshSpWalletForWalletUsecase,
    required this._watchSpWalletUsecase,
    required this._checkSpFeatureGateForWalletUsecase,
  }) : super(const WalletState()) {
    _revisionsSubscription = watchWalletRevisionsUsecase?.execute().listen((
      walletId,
    ) {
      if (!isClosed) add(WalletRevisionChanged(walletId));
    });
    on<WalletRevisionChanged>(_onRevisionChanged);
    on<WalletStarted>(_onStarted, transformer: restartable());
    on<WalletRefreshed>(_onRefreshed, transformer: droppable());
    on<WalletSyncStarted>(_onWalletSyncStarted);
    on<WalletSyncFinished>(_onWalletSyncFinished);
    on<ElectrumSyncResultChanged>(_onElectrumSyncResultChanged);
    on<WalletDeleted>(_onDeleted);
    on<RefreshSpWallet>(_onRefreshSpWallet, transformer: restartable());
    on<SetSpWalletBalance>(_onSetSpWalletBalance);
    on<DismissBackupWarning>(_onDismissBackupWarning);
    on<VerifyBackupStatus>(_onVerifyBackupStatus);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final ReadWalletUsecase _readWalletUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;
  final WatchWalletSyncEventsUsecase _watchWalletSyncEventsUsecase;
  final SyncWalletsUsecase _syncWalletsUsecase;
  final GetUnconfirmedIncomingBalanceUsecase
  _getUnconfirmedIncomingBalanceUsecase;
  final DeleteWalletUsecase _deleteWalletUsecase;
  final CheckBackupNeededUsecase _checkBackupNeededUsecase;
  final GetExternalTorProxyStatusUsecase _getExternalTorProxyStatusUsecase;
  final CheckSpWalletSetupForWalletUsecase _checkSpWalletSetupForWalletUsecase;
  final CheckSpScanningForWalletUsecase _checkSpScanningForWalletUsecase;
  final RefreshSpWalletForWalletUsecase _refreshSpWalletForWalletUsecase;
  final WatchSpWalletUsecase _watchSpWalletUsecase;
  final CheckSpFeatureGateForWalletUsecase _checkSpFeatureGateForWalletUsecase;

  StreamSubscription? _revisionsSubscription;
  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;
  StreamSubscription? _electrumSyncResultsSubscription;
  StreamSubscription? _spUpdatesSubscription;

  int _catalogGeneration = 0;
  int _incomingReadVersion = 0;
  final Map<String, int> _walletUpdateVersions = {};
  final Map<String, int> _walletReadVersions = {};

  bool? _lastBitcoinSyncSuccess;
  bool? _lastLiquidSyncSuccess;
  int _electrumWarningGeneration = 0;
  int _spBalanceUpdateVersion = 0;
  int _backupStatusGeneration = 0;

  @override
  Future<void> close() {
    _revisionsSubscription?.cancel();
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
    _electrumSyncResultsSubscription?.cancel();
    _spUpdatesSubscription?.cancel();
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
    final catalog = ++_catalogGeneration;
    final updates = Map<String, int>.of(_walletUpdateVersions);
    await _spUpdatesSubscription?.cancel();
    _spUpdatesSubscription = _watchSpWalletUsecase.execute().listen((update) {
      switch (update) {
        case SpBalanceChanged(:final totalUnified):
          add(SetSpWalletBalance(totalUnified.value.toInt()));
        case SpSetupChanged():
          add(const RefreshSpWallet());
        case SpChainTipChanged():
          // Only the SP scan policy cares about the tip; the wallet card
          // shows a balance, which SpBalanceChanged already covers.
          break;
      }
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
    // copyWith, not a fresh WalletState: the Silent Payments fields are owned
    // by their own events and must survive a reload.
    _backupStatusGeneration++;
    emit(
      state.copyWith(
        status: WalletStatus.success,
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
    // The result is dropped here because the event dispatched above runs the
    // same sync and puts its failure into WalletState; this await exists only
    // to hold the RefreshIndicator spinner, and its callback must not complete
    // with an error.
    final _ = await _syncWalletsUsecase.execute(trigger: SyncTrigger.user);
  }

  Future<void> _onRefreshed(
    WalletRefreshed event,
    Emitter<WalletState> emit,
  ) async {
    final catalog = _catalogGeneration;
    emit(state.copyWith(isRefreshing: true));

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
      _walletReadVersions.clear();
    }

    add(const RefreshSpWallet());

    _backupStatusGeneration++;
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
    final incomingVersion = ++_incomingReadVersion;
    await _reloadWallet(event.wallet.id, emit);
    if (emit.isDone || catalog != _catalogGeneration || state.wallets.isEmpty) {
      return;
    }

    // This aggregate reads the swap database, never another native wallet.
    final incoming = await _getUnconfirmedIncomingBalanceUsecase.execute(
      walletIds: state.wallets.map((wallet) => wallet.id).toList(),
    );
    if (emit.isDone ||
        catalog != _catalogGeneration ||
        incomingVersion != _incomingReadVersion) {
      return;
    }
    if (incoming case Ok(:final value)) {
      emit(state.copyWith(unconfirmedIncomingBalance: value));
    }
  }

  Future<void> _onElectrumSyncResultChanged(
    ElectrumSyncResultChanged event,
    Emitter<WalletState> emit,
  ) async {
    final generation = ++_electrumWarningGeneration;
    final result = event.result;

    if (result.isLiquid) {
      _lastLiquidSyncSuccess = result.success;
    } else {
      _lastBitcoinSyncSuccess = result.success;
    }

    final bitcoinServerDown = _lastBitcoinSyncSuccess == false;
    final liquidServerDown = _lastLiquidSyncSuccess == false;

    if (bitcoinServerDown || liquidServerDown) {
      final reason = switch ((bitcoinServerDown, liquidServerDown)) {
        (true, true) => ElectrumServerDown.both,
        (true, false) => ElectrumServerDown.bitcoin,
        _ => ElectrumServerDown.liquid,
      };
      final externalTorStatus = bitcoinServerDown
          ? await _getExternalTorProxyStatusUsecase.execute()
          : ExternalTorProxyStatus.disabled;
      if (isClosed || generation != _electrumWarningGeneration) return;
      final warning = WalletWarning(
        reason: reason,
        action:
            bitcoinServerDown &&
                externalTorStatus == ExternalTorProxyStatus.unavailable
            ? WalletWarningAction.torSettings
            : WalletWarningAction.electrumSettings,
        type: WarningType.error,
      );
      emit(state.copyWith(warnings: [warning]));
    } else {
      emit(state.copyWith(warnings: []));
    }
  }

  Future<void> _onDeleted(
    WalletDeleted event,
    Emitter<WalletState> emit,
  ) async {
    final walletId = event.walletId;
    emit(state.copyWith(isDeletingWallet: true, walletDeletionFailure: null));

    switch (await _deleteWalletUsecase.execute(walletId: walletId)) {
      case Ok():
        log.info('[WalletBloc] Wallet with id $walletId deleted successfully');
        _catalogGeneration++;
        // Remove the wallet from the state to directly update the UI
        // without needing to refresh the wallets again
        emit(
          state.copyWith(
            wallets: state.wallets.where((w) => w.id != walletId).toList(),
            isDeletingWallet: false,
          ),
        );
        // Refresh the wallets to ensure everything is up to date
        // and also trigger other things.
        add(const WalletRefreshed());
      case Err(:final failure):
        // Every refusal reaches the sheet as a type, so each one keeps its own
        // wording instead of collapsing into a generic message.
        emit(
          state.copyWith(
            walletDeletionFailure: failure,
            isDeletingWallet: false,
          ),
        );
    }
  }

  // Refreshes the SP card only; it never starts a scan. A scan reaches the
  // Rust side through ScanSpWalletUsecase alone, either from the user tapping
  // Scan or from a sync tick that SpScanPolicy allowed.
  Future<void> _onRefreshSpWallet(
    RefreshSpWallet event,
    Emitter<WalletState> emit,
  ) async {
    // Refresh the SP feature gate (superuser + dev mode) so the wallet card
    // shows exactly when SP is enabled.
    try {
      final enabled = await _checkSpFeatureGateForWalletUsecase.execute();
      emit(state.copyWith(isSpFeatureEnabled: enabled));
    } catch (_) {
      log.warning('SP feature gate refresh failed category=feature_gate');
    }

    final bool isSpWalletSetup;
    switch (await _checkSpWalletSetupForWalletUsecase.execute()) {
      case Ok(:final value):
        isSpWalletSetup = value;
      case Err(:final failure):
        // Settle the SP card (clear loading) rather than leaving it stuck; a
        // failed read is not "not set up", so the flag itself is left alone.
        log.warning(
          '[WalletBloc] SP setup check failed: ${failure.logMessage}',
        );
        emit(state.copyWith(isSpWalletLoading: false));
        return;
    }
    emit(state.copyWith(isSpWalletSetup: isSpWalletSetup));

    // While a scan runs the live session holds the inner lock; refreshing now
    // would block on a snapshot read or time out in dispose() and tear the
    // session down. Skip and keep the current snapshot; the scan's
    // ScanCompleted refresh updates it.
    if (_checkSpScanningForWalletUsecase.execute()) {
      return;
    }

    final balanceUpdateVersion = _spBalanceUpdateVersion;
    emit(state.copyWith(isSpWalletLoading: true));

    // `execute()` (via SpFacade) reads a fresh snapshot from the live session
    // WITHOUT disposing it: the scanner updates the stores in place, so the
    // snapshot is already current. Ok(null) when SP is not set up (gated /
    // `.revoked` sentinel).
    switch (await _refreshSpWalletForWalletUsecase.execute()) {
      case Ok(:final value):
        emit(
          state.copyWith(
            spBalanceSat: balanceUpdateVersion == _spBalanceUpdateVersion
                ? value?.balance.totalUnifiedSat.value.toInt() ?? 0
                : state.spBalanceSat,
            isSpWalletLoading: false,
          ),
        );
      case Err(:final failure):
        // A failed refresh (e.g. a long-running lock-holder still owns the
        // inner mutex) leaves the existing snapshot intact; the next
        // user-triggered refresh retries once the operation completes.
        log.warning('[WalletBloc] SP refresh deferred: ${failure.logMessage}');
        emit(state.copyWith(isSpWalletLoading: false));
    }
  }

  void _onSetSpWalletBalance(
    SetSpWalletBalance event,
    Emitter<WalletState> emit,
  ) {
    // Kept up to date even while the SP card is hidden: a live session keeps
    // pushing after the gate is switched off, and both readers (the card and
    // totalBalance) gate on showSpWallet, so a fresh value never leaks. It is
    // also already right when the gate comes back on.
    _spBalanceUpdateVersion++;
    emit(state.copyWith(spBalanceSat: event.amount));
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
    final result = await _checkBackupNeededUsecase.execute();
    if (generation != _backupStatusGeneration || emit.isDone) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(backupNeeded: value));
      case Err():
        log.warning('recoverbull.backup.status.unavailable');
        emit(state.copyWith(backupNeeded: null));
    }
  }
}
