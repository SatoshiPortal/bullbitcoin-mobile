import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/exchange/data/models/user_summary_model.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_user_summary_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/check_payjoin_relay_health_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_for_tor_initialization_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/home/domain/entity/warning.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required CheckWalletSyncingUsecase checkWalletSyncingUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
    required InitializeTorUsecase initializeTorUsecase,
    required CheckForTorInitializationOnStartupUsecase
    checkForTorInitializationOnStartupUsecase,
    required GetApiKeyUsecase getApiKeyUsecase,
    required GetUserSummaryUseCase getUserSummaryUseCase,
    required GetPrioritizedServerUsecase getBestAvailableServerUsecase,
    required CheckPayjoinRelayHealthUsecase checkPayjoinRelayHealth,
    required GetSwapLimitsUsecase getSwapLimitsUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _checkWalletSyncingUsecase = checkWalletSyncingUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _restartSwapWatcherUsecase = restartSwapWatcherUsecase,
       _initializeTorUsecase = initializeTorUsecase,
       _checkForTorInitializationOnStartupUsecase =
           checkForTorInitializationOnStartupUsecase,
       _getApiKeyUsecase = getApiKeyUsecase,
       _getUserSummaryUsecase = getUserSummaryUseCase,
       _getPrioritizedServerUsecase = getBestAvailableServerUsecase,
       _checkPayjoinRelayHealth = checkPayjoinRelayHealth,
       _getSwapLimitsUsecase = getSwapLimitsUsecase,

       super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
    on<HomeWalletSyncStarted>(_onWalletSyncStarted);
    on<HomeWalletSyncFinished>(_onWalletSyncFinished);
    on<StartTorInitialization>(_onStartTorInitialization);
    on<GetUserDetails>(_onGetUserDetails);
    on<ChangeHomeTab>(_onChangeHomeTab);
    on<CheckAllWarnings>(_onCheckAllWarnings);
    add(const GetUserDetails());
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final RestartSwapWatcherUsecase _restartSwapWatcherUsecase;
  final InitializeTorUsecase _initializeTorUsecase;
  final CheckForTorInitializationOnStartupUsecase
  _checkForTorInitializationOnStartupUsecase;
  final GetApiKeyUsecase _getApiKeyUsecase;
  final GetUserSummaryUseCase _getUserSummaryUsecase;
  final GetPrioritizedServerUsecase _getPrioritizedServerUsecase;

  final CheckPayjoinRelayHealthUsecase _checkPayjoinRelayHealth;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;

  @override
  Future<void> close() {
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
    return super.close();
  }

  void _onChangeHomeTab(ChangeHomeTab event, Emitter<HomeState> emit) {
    emit(state.copyWith(selectedTab: event.selectedTab));
    if (event.selectedTab == HomeTabs.exchange) {
      add(const GetUserDetails());
    }
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    try {
      // Don't sync the wallets here so the wallet list is shown immediately
      // and the sync is done after that
      final wallets = await _getWalletsUsecase.execute();
      final isSyncing = _checkWalletSyncingUsecase.execute();

      emit(
        HomeState(
          status: HomeStatus.success,
          wallets: wallets,
          isSyncing: isSyncing,
        ),
      );

      // Now that the wallets are loaded, we can sync them as done by the refresh
      add(const HomeRefreshed());

      // Now subscribe to syncs starts and finishes to update the UI with the syncing indicator
      await _startedSyncsSubscription
          ?.cancel(); // cancel any previous subscription
      await _finishedSyncsSubscription
          ?.cancel(); // cancel any previous subscription
      _startedSyncsSubscription = _watchStartedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(HomeWalletSyncStarted(wallet)));
      _finishedSyncsSubscription = _watchFinishedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(HomeWalletSyncFinished(wallet)));
    } catch (e) {
      emit(HomeState(status: HomeStatus.failure, error: e));
    }
  }

  Future<void> _onRefreshed(
    HomeRefreshed event,
    Emitter<HomeState> emit,
  ) async {
    try {
      emit(state.copyWith(isSyncing: true));

      final wallets = await _getWalletsUsecase.execute(sync: true);

      emit(
        state.copyWith(
          isSyncing: false,
          status: HomeStatus.success,
          wallets: wallets,
          error: null,
        ),
      );
      add(const CheckAllWarnings());
      // After the wallets are synced we also restart the swap watcher.
      // We do it after the syncing of the wallets to not wait for the
      // swap watcher to be restarted before the wallets are synced.
      await _restartSwapWatcherUsecase.execute();
    } catch (e) {
      emit(
        state.copyWith(isSyncing: false, status: HomeStatus.failure, error: e),
      );
    }
  }

  Future<void> _onWalletSyncStarted(
    HomeWalletSyncStarted event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isSyncing: true));
  }

  Future<void> _onWalletSyncFinished(
    HomeWalletSyncFinished event,
    Emitter<HomeState> emit,
  ) async {
    try {
      //final walletId = event.walletId;

      // To simplify, we just get all wallets, which include the synced one
      //  with the updated balance as well as the other wallets which may or
      //  may not be synced as well.
      final wallets = await _getWalletsUsecase.execute();
      final isAnyOtherWalletSyncing = _checkWalletSyncingUsecase.execute();

      emit(
        state.copyWith(
          status: HomeStatus.success,
          wallets: wallets,
          isSyncing: isAnyOtherWalletSyncing,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure, error: e));
    }
  }

  Future<void> _onStartTorInitialization(
    StartTorInitialization event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(status: HomeStatus.loading));
    final isTorIniatizationEnabled =
        await _checkForTorInitializationOnStartupUsecase.execute();

    if (isTorIniatizationEnabled) {
      await _initializeTorUsecase.execute();
    }
  }

  Future<void> _onGetUserDetails(
    GetUserDetails event,
    Emitter<HomeState> emit,
  ) async {
    try {
      emit(state.copyWith(checkingUser: true));
      final apiKey = await _getApiKeyUsecase.execute();
      if (apiKey == null) throw 'NoApiKeyException';

      final userSummary = await _getUserSummaryUsecase.execute(apiKey.key);
      emit(state.copyWith(userSummary: userSummary, checkingUser: false));
    } catch (e) {
      emit(state.copyWith(error: e, checkingUser: false, userSummary: null));
    }
  }

  Future<void> _onCheckAllWarnings(
    CheckAllWarnings event,
    Emitter<HomeState> emit,
  ) async {
    final defaultWallets = await _getWalletsUsecase.execute(onlyDefaults: true);
    if (defaultWallets.isEmpty) {
      emit(state.copyWith(warnings: const []));
      return;
    }

    // Run all checks in parallel
    final (electrumWarnings, payjoinWarnings, swapWarnings) =
        await (
          _checkElectrumServers(defaultWallets),
          _checkPayjoinHealth(),
          _checkSwapServer(defaultWallets.first.isTestnet),
        ).wait;

    final warnings = [
      if (electrumWarnings != null) electrumWarnings,
      if (payjoinWarnings != null) payjoinWarnings,
      if (swapWarnings != null) swapWarnings,
    ];

    emit(state.copyWith(warnings: warnings));
  }

  Future<HomeWarning?> _checkElectrumServers(
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
      return HomeWarning(
        title: title,
        description: 'Click to configure electrum server settings',
        actionRoute: SettingsRoute.settings.name,
        type: WarningType.error,
      );
    }
    return null;
  }

  Future<HomeWarning?> _checkPayjoinHealth() async {
    final isHealthy = await _checkPayjoinRelayHealth.execute();
    if (!isHealthy) {
      return HomeWarning(
        title: 'Payjoin Service Unreachable',
        description: 'Contact support for assistance',
        actionRoute: SettingsRoute.settings.name,
        type: WarningType.error,
      );
    }

    return null;
  }

  Future<HomeWarning?> _checkSwapServer(bool isTestnet) async {
    try {
      await _getSwapLimitsUsecase.execute(
        type: SwapType.bitcoinToLiquid,
        isTestnet: isTestnet,
      );

      return null;
    } catch (e) {
      return HomeWarning(
        title: 'Boltz Server Unreachable',
        description: 'Contact support for assistance',
        actionRoute: SettingsRoute.settings.name,
        type: WarningType.error,
      );
    }
  }
}
