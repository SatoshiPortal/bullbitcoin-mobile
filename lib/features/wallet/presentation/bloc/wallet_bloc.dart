import 'dart:async';

import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
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
    required this._watchStartedWalletSyncsUsecase,
    required this._watchFinishedWalletSyncsUsecase,
    required this._watchElectrumSyncResultsUsecase,
    required this._syncCoordinator,
    required this._getUnconfirmedIncomingBalanceUsecase,
    required this._deleteWalletUsecase,
    required this._seedStoreTypeDatasource,
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
    on<DismissLegacyStorageWarning>(_onDismissLegacyStorageWarning);
    on<VerifyBackupStatus>(_onVerifyBackupStatus);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final WatchElectrumSyncResultsUsecase _watchElectrumSyncResultsUsecase;
  final SyncCoordinator _syncCoordinator;
  final GetUnconfirmedIncomingBalanceUsecase
  _getUnconfirmedIncomingBalanceUsecase;
  final DeleteWalletUsecase _deleteWalletUsecase;
  final SeedStoreTypeDatasource _seedStoreTypeDatasource;
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
    try {
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

      // Don't sync the wallets here so the wallet list is shown immediately
      // and the sync is done after that
      final wallets = await _getWalletsUsecase.execute();
      final isSyncing = _checkWalletSyncingUsecase.execute();

      // Initialize sync status map with all wallets
      final syncStatus = {
        for (final wallet in wallets)
          wallet.id:
              isSyncing, // If global sync is true, all wallets are syncing
      };

      final seedStoreType = await _seedStoreTypeDatasource.read();
      final isOnLegacyStorage =
          seedStoreType?.toEntity().isLegacyStorage ?? false;

      emit(
        state.copyWith(
          status: WalletStatus.success,
          wallets: wallets,
          syncStatus: syncStatus,
          noWalletsFoundException: null,
          error: null,
          isOnLegacyStorage: isOnLegacyStorage,
        ),
      );

      add(const RefreshSpWallet());

      // Now that the wallets are loaded, we can sync them as done by the refresh
      add(const WalletRefreshed());

      // Now subscribe to syncs starts and finishes to update the UI with the syncing indicator
      await _startedSyncsSubscription?.cancel();
      await _finishedSyncsSubscription?.cancel();
      await _electrumSyncResultsSubscription?.cancel();
      _startedSyncsSubscription = _watchStartedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(WalletSyncStarted(wallet)));
      _finishedSyncsSubscription = _watchFinishedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(WalletSyncFinished(wallet)));
      _electrumSyncResultsSubscription = _watchElectrumSyncResultsUsecase
          .execute()
          .listen((result) => add(ElectrumSyncResultChanged(result)));
    } on NoWalletsFoundException catch (e) {
      emit(
        state.copyWith(
          noWalletsFoundException: e,
          status: WalletStatus.failure,
          error: e,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: WalletStatus.failure, error: e));
    }
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
    try {
      await _syncCoordinator.sync(trigger: SyncTrigger.user);
    } catch (e) {
      log.fine('[WalletBloc] pull-to-refresh sync failed: ${e.runtimeType}');
    }
  }

  Future<void> _onRefreshed(
    WalletRefreshed event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));
    try {
      // SyncCoordinator schedules bitcoin → liquid → swaps → sp sequentially
      // with per-kind dedup, throttling, and a lifecycle gate. A user-triggered
      // refresh (pull-to-refresh) bypasses the throttle; route-driven
      // navigation triggers use SyncTrigger.automatic.
      await _syncCoordinator.sync(trigger: event.trigger);

      final wallets = await _getWalletsUsecase.execute();
      final syncStatus = {for (final wallet in wallets) wallet.id: false};

      add(const RefreshSpWallet());

      emit(
        state.copyWith(
          status: WalletStatus.success,
          wallets: wallets,
          noWalletsFoundException: null,
          error: null,
          syncStatus: syncStatus,
          isRefreshing: false,
        ),
      );
    } on NoWalletsFoundException catch (e) {
      emit(
        state.copyWith(
          noWalletsFoundException: e,
          status: WalletStatus.failure,
          error: e,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: WalletStatus.failure,
          error: e,
          isRefreshing: false,
        ),
      );
    }
  }

  Future<void> _onWalletSyncStarted(
    WalletSyncStarted event,
    Emitter<WalletState> emit,
  ) async {
    try {
      // Update sync status for the wallet that started syncing
      final newSyncStatus = Map<String, bool>.from(state.syncStatus);
      newSyncStatus[event.wallet.id] = true;

      emit(state.copyWith(syncStatus: newSyncStatus));
      final wallets = await _getWalletsUsecase.execute();

      if (wallets.isNotEmpty) {
        final walletIds = wallets.map((w) => w.id).toList();
        final unconfirmedIncomingBalance =
            await _getUnconfirmedIncomingBalanceUsecase.execute(
              walletIds: walletIds,
            );

        emit(
          state.copyWith(
            unconfirmedIncomingBalance: unconfirmedIncomingBalance,
            status: WalletStatus.success,
            error: null,
            noWalletsFoundException: null,
          ),
        );
      }
    } on NoWalletsFoundException catch (e) {
      emit(
        state.copyWith(
          noWalletsFoundException: e,
          status: WalletStatus.failure,
          error: e,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: WalletStatus.failure, error: e));
    }
  }

  Future<void> _onWalletSyncFinished(
    WalletSyncFinished event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final wallets = await _getWalletsUsecase.execute();
      if (wallets.isNotEmpty) {
        final walletIds = wallets.map((w) => w.id).toList();
        final unconfirmedIncomingBalance =
            await _getUnconfirmedIncomingBalanceUsecase.execute(
              walletIds: walletIds,
            );
        emit(
          state.copyWith(
            unconfirmedIncomingBalance: unconfirmedIncomingBalance,
          ),
        );
      }
      // Set sync status to false for the wallet that finished syncing
      final newSyncStatus = Map<String, bool>.from(state.syncStatus);
      newSyncStatus[event.wallet.id] = false;

      emit(
        state.copyWith(
          status: WalletStatus.success,
          wallets: wallets,
          error: null,
          noWalletsFoundException: null,
          syncStatus: newSyncStatus,
        ),
      );
    } on NoWalletsFoundException catch (e) {
      emit(
        state.copyWith(
          noWalletsFoundException: e,
          status: WalletStatus.failure,
          error: e,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: WalletStatus.failure, error: e));
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
      final title = switch ((bitcoinServerDown, liquidServerDown)) {
        (true, true) => 'Bitcoin & Liquid electrum server failure',
        (true, false) => 'Bitcoin electrum server failure',
        (false, true) => 'Liquid electrum server failure',
        _ => '',
      };
      final externalTorStatus = bitcoinServerDown
          ? await _getExternalTorProxyStatusUsecase.execute()
          : ExternalTorProxyStatus.disabled;
      if (isClosed || generation != _electrumWarningGeneration) return;
      final warning = WalletWarning(
        title: title,
        description: 'Click to configure electrum server settings',
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
    try {
      emit(state.copyWith(isDeletingWallet: true, walletDeletionError: null));
      await _deleteWalletUsecase.execute(walletId: event.walletId);
      log.info('[WalletBloc] Wallet with id $walletId deleted successfully');
      // Remove the wallet from the state to directly update the UI
      // without needing to refresh the wallets again

      emit(
        state.copyWith(
          wallets: state.wallets.where((w) => w.id != walletId).toList(),
        ),
      );

      // Refresh the wallets to ensure everything is up to date
      // and also trigger other things.
      add(const WalletRefreshed());
    } on WalletError catch (e) {
      emit(state.copyWith(walletDeletionError: e));
    } catch (e) {
      log.severe(
        message: '[WalletBloc] Failed to delete wallet',
        error: e,
        trace: StackTrace.current,
      );
    } finally {
      emit(state.copyWith(isDeletingWallet: false));
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

  void _onDismissLegacyStorageWarning(
    DismissLegacyStorageWarning event,
    Emitter<WalletState> emit,
  ) {
    emit(state.copyWith(legacyStorageWarningDismissed: true));
  }

  Future<void> _onVerifyBackupStatus(
    VerifyBackupStatus event,
    Emitter<WalletState> emit,
  ) async {
    final dbBackupNeeded = await _checkBackupNeededUsecase.execute();
    if (dbBackupNeeded == state.hasNoBackup()) return;
    final wallets = await _getWalletsUsecase.execute();
    emit(state.copyWith(wallets: wallets));
  }
}
