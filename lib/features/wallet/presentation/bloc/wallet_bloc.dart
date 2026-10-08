import 'dart:async';

import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
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
    required this._getWalletsUsecase,
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

  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;
  StreamSubscription? _electrumSyncResultsSubscription;
  StreamSubscription? _spUpdatesSubscription;

  bool? _lastBitcoinSyncSuccess;
  bool? _lastLiquidSyncSuccess;
  int _electrumWarningGeneration = 0;
  int _spBalanceUpdateVersion = 0;

  @override
  Future<void> close() {
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
    _electrumSyncResultsSubscription?.cancel();
    _spUpdatesSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    WalletStarted event,
    Emitter<WalletState> emit,
  ) async {
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
    switch (await _getWalletsUsecase.execute()) {
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
    // copyWith, not a fresh WalletState: the Silent Payments fields are owned
    // by their own events and must survive a reload.
    emit(
      state.copyWith(
        status: WalletStatus.success,
        wallets: wallets,
        failure: null,
        // If a global sync is running, every wallet is syncing.
        syncStatus: {for (final wallet in wallets) wallet.id: isSyncing},
      ),
    );

    add(const RefreshSpWallet());

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

  /// Pull-to-refresh entry point for the UI. Dispatches a user-triggered
  /// refresh (so the data reload and `isRefreshing` transitions still happen)
  /// and awaits the [SyncCoordinator] directly, so the returned future (and
  /// therefore the RefreshIndicator spinner) resolves only once bitcoin,
  /// liquid, Exchange orders and sp have all synced, rather than tracking the shared
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
      log.warning('Wallet refresh sync: ${failure.logMessage}');
      syncFailure = failure;
    }

    final List<Wallet> wallets;
    switch (await _getWalletsUsecase.execute()) {
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

    add(const RefreshSpWallet());

    emit(
      state.copyWith(
        status: WalletStatus.success,
        wallets: wallets,
        // Carries the sync failure, or clears a previous one. The wallets
        // themselves loaded, so this is a stale-balance warning on top of a
        // correct list, not a failed load.
        failure: syncFailure,
        syncStatus: {for (final wallet in wallets) wallet.id: false},
        isRefreshing: false,
      ),
    );
  }

  Future<void> _onWalletSyncStarted(
    WalletSyncStarted event,
    Emitter<WalletState> emit,
  ) async {
    // Update sync status for the wallet that started syncing
    final newSyncStatus = Map<String, bool>.from(state.syncStatus);
    newSyncStatus[event.wallet.id] = true;

    emit(state.copyWith(syncStatus: newSyncStatus));

    // Only _onStarted and _onRefreshed own `failure`. These per-wallet sync
    // events fire constantly (including from a `finally` after a failed sync),
    // so writing it here would wipe a refresh failure before anyone saw it.
    // A failed read here is logged and the list already on screen is kept.
    final List<Wallet> wallets;
    switch (await _getWalletsUsecase.execute()) {
      case Ok(:final value):
        wallets = value;
      case Err(:final failure):
        log.warning('Wallets read on sync start: ${failure.runtimeType}');
        return;
    }

    if (wallets.isNotEmpty) {
      final walletIds = wallets.map((w) => w.id).toList();
      // A failed read leaves the previous figure in place rather than
      // zeroing a balance the user is looking at.
      final unconfirmedIncomingBalance =
          switch (await _getUnconfirmedIncomingBalanceUsecase.execute(
            walletIds: walletIds,
          )) {
            Ok(:final value) => value,
            Err() => state.unconfirmedIncomingBalance,
          };

      emit(
        state.copyWith(unconfirmedIncomingBalance: unconfirmedIncomingBalance),
      );
    }
  }

  Future<void> _onWalletSyncFinished(
    WalletSyncFinished event,
    Emitter<WalletState> emit,
  ) async {
    // See _onWalletSyncStarted: `failure` is not this handler's to write.
    final List<Wallet> wallets;
    switch (await _getWalletsUsecase.execute()) {
      case Ok(:final value):
        wallets = value;
      case Err(:final failure):
        log.warning('Wallets read on sync finish: ${failure.runtimeType}');
        // Still clear this wallet's spinner: its sync has ended either way.
        final syncStatus = Map<String, bool>.from(state.syncStatus);
        syncStatus[event.wallet.id] = false;
        emit(state.copyWith(syncStatus: syncStatus));
        return;
    }

    if (wallets.isNotEmpty) {
      final walletIds = wallets.map((w) => w.id).toList();
      // A failed read leaves the previous figure in place rather than
      // zeroing a balance the user is looking at.
      final unconfirmedIncomingBalance =
          switch (await _getUnconfirmedIncomingBalanceUsecase.execute(
            walletIds: walletIds,
          )) {
            Ok(:final value) => value,
            Err() => state.unconfirmedIncomingBalance,
          };
      emit(
        state.copyWith(unconfirmedIncomingBalance: unconfirmedIncomingBalance),
      );
    }
    // Set sync status to false for the wallet that finished syncing
    final newSyncStatus = Map<String, bool>.from(state.syncStatus);
    newSyncStatus[event.wallet.id] = false;

    // A successful read resolves a failed load (status failure), so that one
    // is cleared. A sync failure from a refresh leaves status success and is
    // deliberately kept: it is the refresh's to clear, not this event's.
    final recoversFailedLoad = state.status == WalletStatus.failure;
    emit(
      state.copyWith(
        wallets: wallets,
        syncStatus: newSyncStatus,
        status: recoversFailedLoad ? WalletStatus.success : state.status,
        failure: recoversFailedLoad ? null : state.failure,
      ),
    );
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
    } catch (e) {
      log.warning('[WalletBloc] SP feature gate refresh failed: $e');
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
    // A failed check leaves the badge as it is: guessing either way would
    // either nag a user who is backed up or hide a real warning.
    final bool dbBackupNeeded;
    switch (await _checkBackupNeededUsecase.execute()) {
      case Ok(:final value):
        dbBackupNeeded = value;
      case Err(:final failure):
        log.warning('Backup status check: ${failure.logMessage}');
        return;
    }
    if (dbBackupNeeded == state.hasNoBackup()) return;
    // Refreshing the backup badge only: a failed read leaves the current list
    // on screen rather than replacing it with an error.
    if (await _getWalletsUsecase.execute() case Ok(:final value)) {
      emit(state.copyWith(wallets: value));
    }
  }
}
