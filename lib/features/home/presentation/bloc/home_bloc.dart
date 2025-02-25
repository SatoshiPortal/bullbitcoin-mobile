import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required GetWalletsUseCase getWalletsUseCase,
  })  : _getWalletsUseCase = getWalletsUseCase,
        super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
    on<HomeTransactionsSynced>(_onTransactionsSynced);
  }

  final GetWalletsUseCase _getWalletsUseCase;

  Future<void> _onStarted(
    HomeStarted event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final wallets = await _getWalletsUseCase.execute();

      emit(
        HomeState(status: HomeStatus.success, wallets: wallets),
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
      final wallets = await _getWalletsUseCase.execute();

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
    ;
  }

  Future<void> _onTransactionsSynced(
    HomeTransactionsSynced event,
    Emitter<HomeState> emit,
  ) async {
    emit(
      state.copyWith(
        isSyncingTransactions: true,
      ),
    );

    // TODO: Get transactions by implementing and using the Use Case instead of simulating a transaction sync
    //  with a timeout
    await Future.delayed(const Duration(seconds: 2));

    emit(
      state.copyWith(
        isSyncingTransactions: false,
      ),
    );
  }
}
