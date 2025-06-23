import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/swaps/data/services/auto_swap_timer_service.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/listen_to_auto_swap_timer_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/override_fee_block_and_execute_auto_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_for_tor_initialization_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
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
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
    required InitializeTorUsecase initializeTorUsecase,
    required CheckTorRequiredOnStartupUsecase
    checkForTorInitializationOnStartupUsecase,
    required GetPrioritizedServerUsecase getBestAvailableServerUsecase,
    required GetUnconfirmedIncomingBalanceUsecase
    getUnconfirmedIncomingBalanceUsecase,
    required ListenToAutoSwapTimerUsecase listenToAutoSwapTimerUsecase,
    required GetAutoSwapSettingsUsecase getAutoSwapSettingsUsecase,
    required SaveAutoSwapSettingsUsecase saveAutoSwapSettingsUsecase,
    required OverrideFeeBlockAndExecuteAutoSwapUsecase
    overrideFeeBlockAndExecuteAutoSwapUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _checkWalletSyncingUsecase = checkWalletSyncingUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _restartSwapWatcherUsecase = restartSwapWatcherUsecase,
       _initializeTorUsecase = initializeTorUsecase,
       _checkForTorInitializationOnStartupUsecase =
           checkForTorInitializationOnStartupUsecase,
       _getPrioritizedServerUsecase = getBestAvailableServerUsecase,
       _getUnconfirmedIncomingBalanceUsecase =
           getUnconfirmedIncomingBalanceUsecase,
       _listenToAutoSwapTimerUsecase = listenToAutoSwapTimerUsecase,
       _getAutoSwapSettingsUsecase = getAutoSwapSettingsUsecase,
       _saveAutoSwapSettingsUsecase = saveAutoSwapSettingsUsecase,
       _overrideFeeBlockAndExecuteAutoSwapUsecase =
           overrideFeeBlockAndExecuteAutoSwapUsecase,
       super(const WalletState()) {
    on<WalletStarted>(_onStarted);
    on<WalletRefreshed>(_onRefreshed);
    on<WalletSyncStarted>(_onWalletSyncStarted);
    on<WalletSyncFinished>(_onWalletSyncFinished);
    on<StartTorInitialization>(_onStartTorInitialization);
    on<CheckAllWarnings>(_onCheckAllWarnings);
    on<ListenToAutoSwapTimer>(_onListenToAutoSwapTimer);
    on<AutoSwapEventReceived>(_onAutoSwapEventReceived);
    on<BlockAutoSwapUntilNextExecution>(_onBlockAutoSwapUntilNextExecution);
    on<OverrideFeeBlockAndExecuteAutoSwap>(
      _onOverrideFeeBlockAndExecuteAutoSwap,
    );

    // Start listening to auto swap timer when bloc is created
    _initAutoSwapTimer();
  }

  Future<void> _initAutoSwapTimer() async {
    try {
      final wallets = await _getWalletsUsecase.execute();
      final defaultLiquidWallet =
          wallets.where((w) => w.isDefault && w.isLiquid).firstOrNull;
      if (defaultLiquidWallet != null) {
        add(ListenToAutoSwapTimer(defaultLiquidWallet.isTestnet));
      }
    } catch (e) {
      log.severe('[WalletBloc] Failed to initialize auto swap timer: $e');
    }
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final RestartSwapWatcherUsecase _restartSwapWatcherUsecase;
  final InitializeTorUsecase _initializeTorUsecase;
  final CheckTorRequiredOnStartupUsecase
  _checkForTorInitializationOnStartupUsecase;
  final GetPrioritizedServerUsecase _getPrioritizedServerUsecase;
  final GetUnconfirmedIncomingBalanceUsecase
  _getUnconfirmedIncomingBalanceUsecase;
  final ListenToAutoSwapTimerUsecase _listenToAutoSwapTimerUsecase;
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final SaveAutoSwapSettingsUsecase _saveAutoSwapSettingsUsecase;
  final OverrideFeeBlockAndExecuteAutoSwapUsecase
  _overrideFeeBlockAndExecuteAutoSwapUsecase;

  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;
  StreamSubscription? _autoSwapSubscription;

  @override
  Future<void> close() {
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
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

      emit(
        WalletState(
          status: WalletStatus.success,
          wallets: wallets,
          isSyncing: isSyncing,
        ),
      );

      // Now that the wallets are loaded, we can sync them as done by the refresh
      add(const WalletRefreshed());

      // Now subscribe to syncs starts and finishes to update the UI with the syncing indicator
      await _startedSyncsSubscription
          ?.cancel(); // cancel any previous subscription
      await _finishedSyncsSubscription
          ?.cancel(); // cancel any previous subscription
      _startedSyncsSubscription = _watchStartedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(WalletSyncStarted(wallet)));
      _finishedSyncsSubscription = _watchFinishedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(WalletSyncFinished(wallet)));
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
      emit(state.copyWith(isSyncing: true));

      final wallets = await _getWalletsUsecase.execute(sync: true);

      emit(
        state.copyWith(
          isSyncing: false,
          status: WalletStatus.success,
          wallets: wallets,
          noWalletsFoundException: null,
          error: null,
        ),
      );
      add(const CheckAllWarnings());
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
      emit(
        state.copyWith(
          isSyncing: false,
          status: WalletStatus.failure,
          error: e,
        ),
      );
    }
  }

  Future<void> _onWalletSyncStarted(
    WalletSyncStarted event,
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
      emit(
        state.copyWith(
          status: WalletStatus.success,
          wallets: wallets,
          error: null,
          noWalletsFoundException: null,
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

  Future<void> _onCheckAllWarnings(
    CheckAllWarnings event,
    Emitter<WalletState> emit,
  ) async {
    final defaultWallets = await _getWalletsUsecase.execute(onlyDefaults: true);
    if (defaultWallets.isEmpty) {
      emit(state.copyWith(warnings: const []));
      return;
    }

    // Run all checks in parallel
    final electrumWarnings = await _checkElectrumServers(defaultWallets);

    final warnings = [if (electrumWarnings != null) electrumWarnings];

    emit(state.copyWith(warnings: warnings));
  }

  Future<WalletWarning?> _checkElectrumServers(
    List<Wallet> defaultWallets,
  ) async {
    bool bitcoinServerDown = false;
    bool liquidServerDown = false;

    await Future.wait(
      defaultWallets.map((wallet) async {
        final electrumServer = await _getPrioritizedServerUsecase.execute(
          network: wallet.network,
        );

        if (electrumServer.status != ElectrumServerStatus.online) {
          if (wallet.isLiquid) {
            liquidServerDown = true;
          } else {
            bitcoinServerDown = true;
          }
        }
      }),
    );

    if (bitcoinServerDown || liquidServerDown) {
      final title = switch ((bitcoinServerDown, liquidServerDown)) {
        (true, true) => 'Bitcoin & Liquid electrum server failure',
        (true, false) => 'Bitcoin electrum server failure',
        (false, true) => 'Liquid electrum server failure',
        _ => '',
      };
      return WalletWarning(
        title: title,
        description: 'Click to configure electrum server settings',
        actionRoute: SettingsRoute.settings.name,
        type: WarningType.error,
      );
    }
    return null;
  }

  Future<void> _onListenToAutoSwapTimer(
    ListenToAutoSwapTimer event,
    Emitter<WalletState> emit,
  ) async {
    await _autoSwapSubscription?.cancel();

    final stream = _listenToAutoSwapTimerUsecase.execute(
      isTestnet: event.isTestnet,
    );
    _autoSwapSubscription = stream.listen(
      (autoSwapEvent) => add(AutoSwapEventReceived(autoSwapEvent)),
    );

    emit(state.copyWith(isAutoSwapTimerRunning: true));
  }

  void _onAutoSwapEventReceived(
    AutoSwapEventReceived event,
    Emitter<WalletState> emit,
  ) {
    emit(state.copyWith(lastAutoSwapEvent: event.event));

    if (event.event.status == AutoSwapStatus.swapExecuted) {
      // Refresh wallets to show updated balances
      add(const WalletRefreshed());
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
      log.severe('[WalletBloc] Failed to block auto swap: $e');
    }
  }

  Future<void> _onOverrideFeeBlockAndExecuteAutoSwap(
    OverrideFeeBlockAndExecuteAutoSwap event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final defaultLiquidWallet = state.defaultLiquidWallet();
      if (defaultLiquidWallet == null) return;

      await _overrideFeeBlockAndExecuteAutoSwapUsecase.execute(
        isTestnet: defaultLiquidWallet.isTestnet,
      );
    } catch (e) {
      log.severe(
        '[WalletBloc] Failed to override fee block and execute auto swap: $e',
      );
    }
  }
}
