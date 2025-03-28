
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required WalletManagerService walletManagerService,
  })  : _getWalletsUsecase = getWalletsUsecase,
        _walletManagerService = walletManagerService,
        super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
    on<HomeTransactionsSynced>(_onTransactionsSynced);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final WalletManagerService _walletManagerService;

  Future<void> _onStarted(
    HomeStarted event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final wallets = await _getWalletsUsecase.execute();

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
      final wallets = await _getWalletsUsecase.execute();

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

      final wallets = await _walletManagerService.syncAll();
      final List<Wallet> updatedWallets = [];
      for (final w in wallets) {
        final bal = await _walletManagerService.getBalance(
          walletId: w.id,
        );

        updatedWallets.add(w.copyWith(balanceSat: bal.totalSat));
      }

      // TODO: Get transactions by implementing and using the Use Case instead of simulating a transaction sync
      //  with a timeout
      // await Future.delayed(const Duration(seconds: 2));

      emit(
        state.copyWith(
          isSyncingTransactions: false,
          wallets: updatedWallets,
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
