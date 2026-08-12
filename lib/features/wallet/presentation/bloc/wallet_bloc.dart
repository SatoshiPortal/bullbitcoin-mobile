import 'dart:async';

import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/execute_autoswap_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/material.dart';
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
    required this._initializeTorUsecase,
    required this._checkForTorInitializationOnStartupUsecase,
    required this._getUnconfirmedIncomingBalanceUsecase,
    required this._getAutoSwapSettingsUsecase,
    required this._saveAutoSwapSettingsUsecase,
    required this._disableAutoswapWarningUsecase,
    required this._disableAutoswapUsecase,
    required this._executeAutoswapUsecase,
    required this._deleteWalletUsecase,
    required this._seedStoreTypeDatasource,
    required this._checkBackupNeededUsecase,
  }) : super(const WalletState()) {
    on<WalletStarted>(_onStarted);
    on<WalletRefreshed>(_onRefreshed, transformer: droppable());
    on<WalletSyncStarted>(_onWalletSyncStarted);
    on<WalletSyncFinished>(_onWalletSyncFinished);
    on<ElectrumSyncResultChanged>(_onElectrumSyncResultChanged);
    on<StartTorInitialization>(_onStartTorInitialization);
    on<BlockAutoSwapUntilNextExecution>(_onBlockAutoSwapUntilNextExecution);
    on<ExecuteAutoSwap>(_onExecuteAutoSwap);
    on<ExecuteAutoSwapFeeOverride>(_onExecuteAutoSwapFeeOverride);
    on<WalletDeleted>(_onDeleted);
    on<DismissAutoSwapWarning>(_onDismissAutoSwapWarning);
    on<DisableAutoSwap>(_onDisableAutoSwap);
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
  final InitTorUsecase _initializeTorUsecase;
  final IsTorRequiredUsecase _checkForTorInitializationOnStartupUsecase;
  final GetUnconfirmedIncomingBalanceUsecase
  _getUnconfirmedIncomingBalanceUsecase;
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final SaveAutoSwapSettingsUsecase _saveAutoSwapSettingsUsecase;
  final DisableAutoswapWarningUsecase _disableAutoswapWarningUsecase;
  final DisableAutoswapUsecase _disableAutoswapUsecase;
  final ExecuteAutoswapUsecase _executeAutoswapUsecase;
  final DeleteWalletUsecase _deleteWalletUsecase;
  final SeedStoreTypeDatasource _seedStoreTypeDatasource;
  final CheckBackupNeededUsecase _checkBackupNeededUsecase;

  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;
  StreamSubscription? _electrumSyncResultsSubscription;
  StreamSubscription? _autoSwapSubscription;

  bool? _lastBitcoinSyncSuccess;
  bool? _lastLiquidSyncSuccess;

  @override
  Future<void> close() {
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
    _electrumSyncResultsSubscription?.cancel();
    _autoSwapSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    WalletStarted event,
    Emitter<WalletState> emit,
  ) async {
    try {
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
        WalletState(
          status: WalletStatus.success,
          wallets: wallets,
          syncStatus: syncStatus,
          isOnLegacyStorage: isOnLegacyStorage,
        ),
      );

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
      emit(WalletState(status: WalletStatus.failure, error: e));
    }
  }

  /// Pull-to-refresh entry point for the UI. Dispatches a user-triggered
  /// refresh (so the data reload and `isRefreshing` transitions still happen)
  /// and awaits the [SyncCoordinator] directly, so the returned future — and
  /// therefore the RefreshIndicator spinner — resolves only once bitcoin,
  /// liquid and Exchange orders have all synced, rather than tracking the shared
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
      // SyncCoordinator schedules bitcoin → liquid sequentially with
      // per-kind dedup, throttling, and a lifecycle gate. A user-triggered
      // refresh (pull-to-refresh) bypasses the throttle; route-driven
      // navigation triggers use SyncTrigger.automatic.
      await _syncCoordinator.sync(trigger: event.trigger);

      final wallets = await _getWalletsUsecase.execute();
      final syncStatus = {for (final wallet in wallets) wallet.id: false};

      final defaultLiquidWallet = wallets
          .where((wallet) => wallet.isDefault && wallet.network.isLiquid)
          .firstOrNull;

      AutoSwap? autoSwapSettings;
      if (defaultLiquidWallet != null) {
        try {
          autoSwapSettings = await _getAutoSwapSettingsUsecase.execute();
        } catch (e) {
          log.fine('Failed to load autoswap settings: $e');
        }
      }

      emit(
        state.copyWith(
          status: WalletStatus.success,
          wallets: wallets,
          noWalletsFoundException: null,
          error: null,
          syncStatus: syncStatus,
          autoSwapSettings: autoSwapSettings,
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
      if (event.wallet.isLiquid && !state.autoSwapExecuting) {
        debugPrint(
          'onWalletSyncFinished(Liquid): Starting Auto Swap Execution',
        );
        add(const ExecuteAutoSwap());
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
      final warning = WalletWarning(
        title: title,
        description: 'Click to configure electrum server settings',
        actionRoute: ElectrumSettingsRoute.electrumSettings.name,
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

  Future<void> _onStartTorInitialization(
    StartTorInitialization event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(status: WalletStatus.loading));
    final isTorIniatizationEnabled =
        await _checkForTorInitializationOnStartupUsecase.execute();

    if (isTorIniatizationEnabled) {
      await _initializeTorUsecase.execute();
    }
  }

  Future<void> _onBlockAutoSwapUntilNextExecution(
    BlockAutoSwapUntilNextExecution event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final defaultLiquidWallet = state.defaultLiquidWallet();
      if (defaultLiquidWallet == null) return;

      final currentSettings = await _getAutoSwapSettingsUsecase.execute();

      await _saveAutoSwapSettingsUsecase.execute(
        currentSettings.copyWith(blockTillNextExecution: true),
      );

      // Update the state with the new settings
      emit(
        state.copyWith(
          autoSwapSettings: currentSettings.copyWith(
            blockTillNextExecution: true,
          ),
        ),
      );
    } catch (e) {
      log.severe(
        message: '[WalletBloc] Failed to block auto swap',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  Future<void> _onExecuteAutoSwap(
    ExecuteAutoSwap event,
    Emitter<WalletState> emit,
  ) async {
    if (state.autoSwapExecuting) return;
    emit(state.copyWith(autoSwapExecuting: true));
    try {
      final result = await _executeAutoswapUsecase.execute();
      switch (result) {
        case Ok(:final value):
          log.info('[WalletBloc] Autoswap executed: $value');
        case Err(:final failure):
          // Guards (disabled, insufficient balance, …) are expected — log
          // at fine level. Real execution errors are logged at warning.
          if (failure is AutoswapExecutionFailure) {
            log.warning('[WalletBloc] Autoswap execution failed', error: failure);
          } else {
            log.fine('[WalletBloc] Autoswap skipped: ${failure.runtimeType}');
          }
      }
    } catch (e) {
      log.severe(
        message: '[WalletBloc] Autoswap execution crashed',
        error: e,
        trace: StackTrace.current,
      );
    } finally {
      if (!isClosed) {
        emit(state.copyWith(autoSwapExecuting: false));
      }
    }
  }

  Future<void> _onExecuteAutoSwapFeeOverride(
    ExecuteAutoSwapFeeOverride event,
    Emitter<WalletState> emit,
  ) => _onExecuteAutoSwap(const ExecuteAutoSwap(), emit);

  Future<void> _onDismissAutoSwapWarning(
    DismissAutoSwapWarning event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final defaultLiquidWallet = state.defaultLiquidWallet();
      if (defaultLiquidWallet == null) return;

      final updatedSettings = await _disableAutoswapWarningUsecase.execute();

      emit(state.copyWith(autoSwapSettings: updatedSettings));
    } catch (e) {
      log.severe(
        message: '[WalletBloc] Failed to dismiss autoswap warning',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  Future<void> _onDisableAutoSwap(
    DisableAutoSwap event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final defaultLiquidWallet = state.defaultLiquidWallet();
      if (defaultLiquidWallet == null) return;

      final updatedSettings = await _disableAutoswapUsecase.execute();

      emit(state.copyWith(autoSwapSettings: updatedSettings));
    } catch (e) {
      log.severe(
        message: '[WalletBloc] Failed to disable autoswap',
        error: e,
        trace: StackTrace.current,
      );
    }
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
