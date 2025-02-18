import 'package:bb_mobile/core/domain/usecases/get_default_wallets_metadata_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallet_balance_sat_usecase.dart';
import 'package:bb_mobile/features/home/presentation/view_models/wallet_card_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required GetDefaultWalletsMetadataUseCase getDefaultWalletsMetadataUseCase,
    required GetWalletBalanceSatUseCase getWalletBalanceSatUseCase,
  })  : _getDefaultWalletsMetadataUseCase = getDefaultWalletsMetadataUseCase,
        _getWalletBalanceSatUseCase = getWalletBalanceSatUseCase,
        super(const HomeState.initial()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
    on<HomeTransactionsSynced>(_onTransactionsSynced);
  }

  final GetDefaultWalletsMetadataUseCase _getDefaultWalletsMetadataUseCase;
  final GetWalletBalanceSatUseCase _getWalletBalanceSatUseCase;

  Future<void> _onStarted(
    HomeStarted event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final wallets = await _getDefaultWalletsMetadataUseCase.execute();
      final walletCards = await Future.wait(
        wallets.map((wallet) async {
          final balance = await _getWalletBalanceSatUseCase.execute(wallet.id);
          return WalletCardViewModel(
            walletId: wallet.id,
            name: wallet.name,
            network: wallet.network,
            balanceSat: balance.totalSat,
          );
        }),
      );
      final bitcoinWalletCard =
          walletCards.where((card) => card.network.isBitcoin).first;
      final liquidWalletCard =
          walletCards.where((card) => card.network.isLiquid).first;

      emit(
        HomeState.success(
          liquidWalletCard: liquidWalletCard,
          bitcoinWalletCard: bitcoinWalletCard,
        ),
      );
    } catch (e) {
      emit(HomeState.failure(error: e));
    }
  }

  Future<void> _onRefreshed(
    HomeRefreshed event,
    Emitter<HomeState> emit,
  ) async {
    state.mapOrNull(
      success: (successState) async {
        try {
          // Run both balance fetches in parallel
          final results = await Future.wait([
            _getWalletBalanceSatUseCase
                .execute(successState.bitcoinWalletCard.walletId),
            _getWalletBalanceSatUseCase
                .execute(successState.liquidWalletCard.walletId),
          ]);

          emit(
            successState.copyWith(
              bitcoinWalletCard: successState.bitcoinWalletCard.copyWith(
                balanceSat: results[0].totalSat,
              ),
              liquidWalletCard: successState.liquidWalletCard.copyWith(
                balanceSat: results[1].totalSat,
              ),
            ),
          );
        } catch (e) {
          // Just keep the previous state if refreshing fails
        }
      },
    );
  }

  Future<void> _onTransactionsSynced(
    HomeTransactionsSynced event,
    Emitter<HomeState> emit,
  ) async {
    state.mapOrNull(
      success: (successState) async {
        emit(
          successState.copyWith(
            isSyncingTransactions: true,
          ),
        );

        // TODO: Get transactions by implementing and using the Use Case instead of simulating a transaction sync
        //  with a timeout
        await Future.delayed(const Duration(seconds: 2));

        emit(
          successState.copyWith(
            isSyncingTransactions: false,
          ),
        );
      },
    );
  }
}
