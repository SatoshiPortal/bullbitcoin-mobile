import 'dart:async';

import 'package:bb_mobile/core/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core/ark/usecases/check_ark_wallet_setup_usecase.dart';
import 'package:bb_mobile/core/ark/usecases/get_ark_wallet_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/errors/autoswap_errors.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/auto_swap_execution_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_bloc.freezed.dart';
part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required CheckWalletSyncingUsecase checkWalletSyncingUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required WatchElectrumSyncResultsUsecase watchElectrumSyncResultsUsecase,
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
    required InitTorUsecase initializeTorUsecase,
    required IsTorRequiredUsecase checkForTorInitializationOnStartupUsecase,
    required GetUnconfirmedIncomingBalanceUsecase
    getUnconfirmedIncomingBalanceUsecase,
    required GetAutoSwapSettingsUsecase getAutoSwapSettingsUsecase,
    required SaveAutoSwapSettingsUsecase saveAutoSwapSettingsUsecase,
    required DisableAutoswapWarningUsecase disableAutoswapWarningUsecase,
    required DisableAutoswapUsecase disableAutoswapUsecase,
    required AutoSwapExecutionUsecase autoSwapExecutionUsecase,
    required DeleteWalletUsecase deleteWalletUsecase,
    required GetArkWalletUsecase getArkWalletUsecase,
    required CheckArkWalletSetupUsecase checkArkWalletSetupUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _checkWalletSyncingUsecase = checkWalletSyncingUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _watchElectrumSyncResultsUsecase = watchElectrumSyncResultsUsecase,
       _restartSwapWatcherUsecase = restartSwapWatcherUsecase,
       _initializeTorUsecase = initializeTorUsecase,
       _checkForTorInitializationOnStartupUsecase =
           checkForTorInitializationOnStartupUsecase,
       _getUnconfirmedIncomingBalanceUsecase =
           getUnconfirmedIncomingBalanceUsecase,
       _getAutoSwapSettingsUsecase = getAutoSwapSettingsUsecase,
       _saveAutoSwapSettingsUsecase = saveAutoSwapSettingsUsecase,
       _disableAutoswapWarningUsecase = disableAutoswapWarningUsecase,
       _disableAutoswapUsecase = disableAutoswapUsecase,
       _autoSwapExecutionUsecase = autoSwapExecutionUsecase,
       _deleteWalletUsecase = deleteWalletUsecase,
       _getArkWalletUsecase = getArkWalletUsecase,
       _checkArkWalletSetupUsecase = checkArkWalletSetupUsecase,
       super(const WalletState()) {
    on<WalletStarted>(_onStarted);
    on<WalletRefreshed>(_onRefreshed);
    on<WalletSyncStarted>(_onWalletSyncStarted);
    on<WalletSyncFinished>(_onWalletSyncFinished);
    on<ElectrumSyncResultChanged>(_onElectrumSyncResultChanged);
    on<StartTorInitialization>(_onStartTorInitialization);
    on<BlockAutoSwapUntilNextExecution>(_onBlockAutoSwapUntilNextExecution);
    on<ExecuteAutoSwap>(_onExecuteAutoSwap);
    on<ExecuteAutoSwapFeeOverride>(_onExecuteAutoSwapFeeOverride);
    on<WalletDeleted>(_onDeleted);
    on<RefreshArkWalletBalance>(_onRefreshArkWalletBalance);
    on<DismissAutoSwapWarning>(_onDismissAutoSwapWarning);
    on<DisableAutoSwap>(_onDisableAutoSwap);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final WatchElectrumSyncResultsUsecase _watchElectrumSyncResultsUsecase;
  final RestartSwapWatcherUsecase _restartSwapWatcherUsecase;
  final InitTorUsecase _initializeTorUsecase;
  final IsTorRequiredUsecase _checkForTorInitializationOnStartupUsecase;
  final GetUnconfirmedIncomingBalanceUsecase
  _getUnconfirmedIncomingBalanceUsecase;
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final SaveAutoSwapSettingsUsecase _saveAutoSwapSettingsUsecase;
  final DisableAutoswapWarningUsecase _disableAutoswapWarningUsecase;
  final DisableAutoswapUsecase _disableAutoswapUsecase;
  final AutoSwapExecutionUsecase _autoSwapExecutionUsecase;
  final DeleteWalletUsecase _deleteWalletUsecase;
  final GetArkWalletUsecase _getArkWalletUsecase;
  final CheckArkWalletSetupUsecase _checkArkWalletSetupUsecase;

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

      emit(
        WalletState(
          status: WalletStatus.success,
          wallets: wallets,
          syncStatus: syncStatus,
        ),
      );

      add(const RefreshArkWalletBalance());

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

  Future<void> _onRefreshed(
    WalletRefreshed event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final wallets = await _getWalletsUsecase.execute(sync: true);

      // Initialize all wallets as not syncing
      final syncStatus = {for (final wallet in wallets) wallet.id: false};

      add(const RefreshArkWalletBalance());

      final defaultLiquidWallet = wallets
          .where((wallet) => wallet.isDefault && wallet.network.isLiquid)
          .firstOrNull;

      AutoSwap? autoSwapSettings;
      if (defaultLiquidWallet != null) {
        try {
          autoSwapSettings = await _getAutoSwapSettingsUsecase.execute(
            isTestnet: defaultLiquidWallet.isTestnet,
          );
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
        ),
      );
      // After the wallets are synced we also restart the swap watcher.
      // We do it after the syncing of the wallets to not wait for the
      // swap watcher to be restarted before the wallets are synced.
      await _restartSwapWatcherUsecase.execute();
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

      final isTestnet = defaultLiquidWallet.isTestnet;
      final currentSettings = await _getAutoSwapSettingsUsecase.execute(
        isTestnet: isTestnet,
      );

      await _saveAutoSwapSettingsUsecase.execute(
        currentSettings.copyWith(blockTillNextExecution: true),
        isTestnet: isTestnet,
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
    try {
      emit(state.copyWith(autoSwapExecuting: true));
      final defaultLiquidWallet = state.defaultLiquidWallet();
      if (defaultLiquidWallet == null) return;
      final autoSwapSettings = await _getAutoSwapSettingsUsecase.execute(
        isTestnet: defaultLiquidWallet.isTestnet,
      );
      emit(state.copyWith(autoSwapSettings: autoSwapSettings));
      if (!autoSwapSettings.enabled) {
        emit(state.copyWith(autoSwapExecuting: false));
        return;
      }
      await _autoSwapExecutionUsecase.execute(
        isTestnet: defaultLiquidWallet.isTestnet,
        feeBlock: true,
      );

      emit(
        state.copyWith(
          autoSwapFeeLimitExceeded: false,
          autoSwapExecuting: false,
        ),
      );
    } on BalanceThresholdException catch (e) {
      debugPrint('[WalletBloc] Auto swap balance threshold not met: $e');
      emit(state.copyWith(autoSwapExecuting: false));
    } on FeeBlockException catch (e) {
      debugPrint('[WalletBloc] Auto swap fee block exceeded: $e');
      emit(
        state.copyWith(
          autoSwapFeeLimitExceeded: true,
          currentSwapFeePercent: e.currentFeePercent,
          autoSwapExecuting: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(autoSwapExecuting: false));
      log.severe(
        message: '[WalletBloc] Failed to execute auto swap',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  Future<void> _onExecuteAutoSwapFeeOverride(
    ExecuteAutoSwapFeeOverride event,
    Emitter<WalletState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          autoSwapFeeLimitExceeded: false,
          autoSwapExecuting: true,
        ),
      );

      final defaultLiquidWallet = state.defaultLiquidWallet();
      if (defaultLiquidWallet == null) return;
      final autoSwapSettings = await _getAutoSwapSettingsUsecase.execute(
        isTestnet: defaultLiquidWallet.isTestnet,
      );
      emit(state.copyWith(autoSwapSettings: autoSwapSettings));
      if (!autoSwapSettings.enabled) {
        emit(state.copyWith(autoSwapExecuting: false));
        return;
      }

      await _autoSwapExecutionUsecase.execute(
        isTestnet: defaultLiquidWallet.isTestnet,
        feeBlock: false,
      );
      emit(
        state.copyWith(
          autoSwapFeeLimitExceeded: false,
          autoSwapExecuting: false,
        ),
      );
    } on BalanceThresholdException catch (e) {
      debugPrint('[WalletBloc] Auto swap balance threshold not met: $e');
      emit(state.copyWith(autoSwapExecuting: false));
    } on FeeBlockException catch (e) {
      debugPrint('[WalletBloc] Auto swap fee block exceeded: $e');
      emit(
        state.copyWith(
          autoSwapFeeLimitExceeded: true,
          currentSwapFeePercent: e.currentFeePercent,
          autoSwapExecuting: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(autoSwapExecuting: false));
      log.severe(
        message: '[WalletBloc] Failed to execute auto swap ',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  Future<void> _onRefreshArkWalletBalance(
    RefreshArkWalletBalance event,
    Emitter<WalletState> emit,
  ) async {
    if (event.amount != null) {
      emit(state.copyWith(arkBalanceSat: event.amount!));
      return;
    } else {
      // First check if Ark wallet is set up
      final isArkWalletSetup = await _checkArkWalletSetupUsecase.execute();
      emit(state.copyWith(isArkWalletSetup: isArkWalletSetup));

      if (!isArkWalletSetup) {
        return;
      }

      // If set up, show loading state and load the wallet
      emit(state.copyWith(isArkWalletLoading: true));

      try {
        final arkWallet = await _getArkWalletUsecase.execute();
        final arkBalance = await arkWallet?.balance;
        emit(
          state.copyWith(
            arkWallet: arkWallet,
            arkBalanceSat: arkBalance?.completeTotal ?? 0,
            isArkWalletLoading: false,
          ),
        );
      } catch (e) {
        emit(state.copyWith(isArkWalletLoading: false));
      }
    }
  }

  Future<void> _onDismissAutoSwapWarning(
    DismissAutoSwapWarning event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final defaultLiquidWallet = state.defaultLiquidWallet();
      if (defaultLiquidWallet == null) return;

      final updatedSettings = await _disableAutoswapWarningUsecase.execute(
        isTestnet: defaultLiquidWallet.isTestnet,
      );

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

      final updatedSettings = await _disableAutoswapUsecase.execute(
        isTestnet: defaultLiquidWallet.isTestnet,
      );

      emit(state.copyWith(autoSwapSettings: updatedSettings));
    } catch (e) {
      log.severe(
        message: '[WalletBloc] Failed to disable autoswap',
        error: e,
        trace: StackTrace.current,
      );
    }
  }
}
