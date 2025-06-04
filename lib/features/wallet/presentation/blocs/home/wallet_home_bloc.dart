import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/exchange/data/models/user_summary_model.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_for_tor_initialization_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_home_bloc.freezed.dart';
part 'wallet_home_event.dart';
part 'wallet_home_state.dart';

class WalletHomeBloc extends Bloc<WalletHomeEvent, WalletHomeState> {
  WalletHomeBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required CheckWalletSyncingUsecase checkWalletSyncingUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
    required InitializeTorUsecase initializeTorUsecase,
    required CheckForTorInitializationOnStartupUsecase
    checkForTorInitializationOnStartupUsecase,
    required GetPrioritizedServerUsecase getBestAvailableServerUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _checkWalletSyncingUsecase = checkWalletSyncingUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _restartSwapWatcherUsecase = restartSwapWatcherUsecase,
       _initializeTorUsecase = initializeTorUsecase,
       _checkForTorInitializationOnStartupUsecase =
           checkForTorInitializationOnStartupUsecase,
       _getPrioritizedServerUsecase = getBestAvailableServerUsecase,

       super(const WalletHomeState()) {
    on<WalletHomeStarted>(_onStarted);
    on<WalletHomeRefreshed>(_onRefreshed);
    on<WalletHomeWalletSyncStarted>(_onWalletSyncStarted);
    on<WalletHomeWalletSyncFinished>(_onWalletSyncFinished);
    on<StartTorInitialization>(_onStartTorInitialization);
    on<CheckAllWarnings>(_onCheckAllWarnings);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final RestartSwapWatcherUsecase _restartSwapWatcherUsecase;
  final InitializeTorUsecase _initializeTorUsecase;
  final CheckForTorInitializationOnStartupUsecase
  _checkForTorInitializationOnStartupUsecase;
  final GetPrioritizedServerUsecase _getPrioritizedServerUsecase;

  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;

  @override
  Future<void> close() {
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    WalletHomeStarted event,
    Emitter<WalletHomeState> emit,
  ) async {
    try {
      // Don't sync the wallets here so the wallet list is shown immediately
      // and the sync is done after that
      final wallets = await _getWalletsUsecase.execute();
      final isSyncing = _checkWalletSyncingUsecase.execute();

      emit(
        WalletHomeState(
          status: WalletHomeStatus.success,
          wallets: wallets,
          isSyncing: isSyncing,
        ),
      );

      // Now that the wallets are loaded, we can sync them as done by the refresh
      add(const WalletHomeRefreshed());

      // Now subscribe to syncs starts and finishes to update the UI with the syncing indicator
      await _startedSyncsSubscription
          ?.cancel(); // cancel any previous subscription
      await _finishedSyncsSubscription
          ?.cancel(); // cancel any previous subscription
      _startedSyncsSubscription = _watchStartedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(WalletHomeWalletSyncStarted(wallet)));
      _finishedSyncsSubscription = _watchFinishedWalletSyncsUsecase
          .execute()
          .listen((wallet) => add(WalletHomeWalletSyncFinished(wallet)));
    } catch (e) {
      emit(WalletHomeState(status: WalletHomeStatus.failure, error: e));
    }
  }

  Future<void> _onRefreshed(
    WalletHomeRefreshed event,
    Emitter<WalletHomeState> emit,
  ) async {
    try {
      emit(state.copyWith(isSyncing: true));

      final wallets = await _getWalletsUsecase.execute(sync: true);

      emit(
        state.copyWith(
          isSyncing: false,
          status: WalletHomeStatus.success,
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
        state.copyWith(
          isSyncing: false,
          status: WalletHomeStatus.failure,
          error: e,
        ),
      );
    }
  }

  Future<void> _onWalletSyncStarted(
    WalletHomeWalletSyncStarted event,
    Emitter<WalletHomeState> emit,
  ) async {
    // Do nothing for now, since we only want to show the syncing indicator
    // when the user itself refreshes the wallets.
  }

  Future<void> _onWalletSyncFinished(
    WalletHomeWalletSyncFinished event,
    Emitter<WalletHomeState> emit,
  ) async {
    try {
      //final walletId = event.walletId;

      // To simplify, we just get all wallets, which include the synced one
      //  with the updated balance as well as the other wallets which may or
      //  may not be synced as well.
      final wallets = await _getWalletsUsecase.execute();
      // No need to check if any other wallet is syncing, since we don't want to
      // show the syncing indicator for automatic syncs anymore.
      //final isAnyOtherWalletSyncing = _checkWalletSyncingUsecase.execute();

      emit(
        state.copyWith(
          status: WalletHomeStatus.success,
          wallets: wallets,
          //isSyncing: isAnyOtherWalletSyncing,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: WalletHomeStatus.failure, error: e));
    }
  }

  Future<void> _onStartTorInitialization(
    StartTorInitialization event,
    Emitter<WalletHomeState> emit,
  ) async {
    emit(state.copyWith(status: WalletHomeStatus.loading));
    final isTorIniatizationEnabled =
        await _checkForTorInitializationOnStartupUsecase.execute();

    if (isTorIniatizationEnabled) {
      await _initializeTorUsecase.execute();
    }
  }

  Future<void> _onCheckAllWarnings(
    CheckAllWarnings event,
    Emitter<WalletHomeState> emit,
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
}
