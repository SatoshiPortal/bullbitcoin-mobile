import 'dart:async';

import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/check_for_tor_initialization_usecase.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_any_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required CheckAnyWalletSyncingUsecase checkAnyWalletSyncingUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
    required InitializeTorUsecase initializeTorUsecase,
    required CheckForTorInitializationOnStartupUsecase
        checkForTorInitializationOnStartupUsecase,
  })  : _getWalletsUsecase = getWalletsUsecase,
        _checkAnyWalletSyncingUsecase = checkAnyWalletSyncingUsecase,
        _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
        _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
        _restartSwapWatcherUsecase = restartSwapWatcherUsecase,
        _initializeTorUsecase = initializeTorUsecase,
        _checkForTorInitializationOnStartupUsecase =
            checkForTorInitializationOnStartupUsecase,
        super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
    on<HomeWalletSyncStarted>(_onWalletSyncStarted);
    on<HomeWalletSyncFinished>(_onWalletSyncFinished);
    on<StartTorInitialization>(_onStartTorInitialization);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final CheckAnyWalletSyncingUsecase _checkAnyWalletSyncingUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final RestartSwapWatcherUsecase _restartSwapWatcherUsecase;
  final InitializeTorUsecase _initializeTorUsecase;
  final CheckForTorInitializationOnStartupUsecase
      _checkForTorInitializationOnStartupUsecase;
  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;

  @override
  Future<void> close() {
    _startedSyncsSubscription?.cancel();
    _finishedSyncsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    HomeStarted event,
    Emitter<HomeState> emit,
  ) async {
    try {
      // Don't sync the wallets here so the wallet list is shown immediately
      // and the sync is done after that
      final wallets = await _getWalletsUsecase.execute();
      final isSyncing = _checkAnyWalletSyncingUsecase.execute();

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
      _startedSyncsSubscription =
          _watchStartedWalletSyncsUsecase.execute().listen(
                (wallet) => add(HomeWalletSyncStarted(wallet)),
              );
      _finishedSyncsSubscription =
          _watchFinishedWalletSyncsUsecase.execute().listen(
                (wallet) => add(HomeWalletSyncFinished(wallet)),
              );
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

      // After the wallets are synced we also restart the swap watcher.
      // We do it after the syncing of the wallets to not wait for the
      // swap watcher to be restarted before the wallets are synced.
      await _restartSwapWatcherUsecase.execute();
    } catch (e) {
      emit(
        state.copyWith(
          isSyncing: false,
          status: HomeStatus.failure,
          error: e,
        ),
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
      final isAnyOtherWalletSyncing = _checkAnyWalletSyncingUsecase.execute();

      emit(state.copyWith(
        status: HomeStatus.success,
        wallets: wallets,
        isSyncing: isAnyOtherWalletSyncing,
      ));
    } catch (e) {
      emit(
        state.copyWith(
          status: HomeStatus.failure,
          error: e,
        ),
      );
    }
  }

  Future<void> _onStartTorInitialization(
    StartTorInitialization event,
    Emitter<HomeState> emit,
  ) async {
    emit(
      state.copyWith(
        status: HomeStatus.loading,
      ),
    );
    final isTorIniatizationEnabled =
        await _checkForTorInitializationOnStartupUsecase.execute();

    if (isTorIniatizationEnabled) {
      await _initializeTorUsecase.execute();
    }
  }
}
