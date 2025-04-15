import 'dart:async';

import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_any_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_syncs_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required CheckAnyWalletSyncingUsecase checkAnyWalletSyncingUsecase,
    required WatchWalletSyncsUsecase watchWalletSyncsUsecase,
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
  })  : _getWalletsUsecase = getWalletsUsecase,
        _checkAnyWalletSyncingUsecase = checkAnyWalletSyncingUsecase,
        _watchWalletSyncsUsecase = watchWalletSyncsUsecase,
        _restartSwapWatcherUsecase = restartSwapWatcherUsecase,
        super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
    on<HomeWalletSynced>(_onWalletSynced);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final CheckAnyWalletSyncingUsecase _checkAnyWalletSyncingUsecase;
  final WatchWalletSyncsUsecase _watchWalletSyncsUsecase;
  final RestartSwapWatcherUsecase _restartSwapWatcherUsecase;
  StreamSubscription? _syncsSubscription;

  @override
  Future<void> close() {
    _syncsSubscription?.cancel();
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

      // Now subscribe to future syncs to update the UI
      await _syncsSubscription?.cancel(); // cancel any previous subscription
      _syncsSubscription = _watchWalletSyncsUsecase.execute().listen(
            (walletId) => add(HomeWalletSynced(walletId)),
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

  Future<void> _onWalletSynced(
    HomeWalletSynced event,
    Emitter<HomeState> emit,
  ) async {
    try {
      //final walletId = event.walletId;

      // We just get all wallets, which include the synced one with the updated
      // balance.
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
}
