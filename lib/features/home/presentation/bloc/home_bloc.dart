import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required RestartSwapWatcherUsecase restartSwapWatcherUsecase,
  })  : _getWalletsUsecase = getWalletsUsecase,
        _restartSwapWatcherUsecase = restartSwapWatcherUsecase,
        super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
    on<HomeTransactionsSynced>(_onTransactionsSynced);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final RestartSwapWatcherUsecase _restartSwapWatcherUsecase;

  Future<void> _onStarted(
    HomeStarted event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final wallets = await _getWalletsUsecase.execute(sync: true);

      emit(
        HomeState(status: HomeStatus.success, wallets: wallets),
      );

      add(const HomeTransactionsSynced());
    } catch (e) {
      emit(HomeState(status: HomeStatus.failure, error: e));
    }
  }

  Future<void> _onRefreshed(
    HomeRefreshed event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final wallets = await _getWalletsUsecase.execute(sync: true);

      emit(
        state.copyWith(
          status: HomeStatus.success,
          wallets: wallets,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: HomeStatus.failure,
          error: e,
        ),
      );
    }
  }

  Future<void> _onTransactionsSynced(
    HomeTransactionsSynced event,
    Emitter<HomeState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          isSyncingTransactions: true,
        ),
      );
      await _restartSwapWatcherUsecase.execute();
      final wallets = await _getWalletsUsecase.execute(sync: true);

      emit(
        state.copyWith(
          isSyncingTransactions: false,
          wallets: wallets,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSyncingTransactions: false,
          error: e,
        ),
      );
    }
  }
}
