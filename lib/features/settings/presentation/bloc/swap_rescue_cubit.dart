import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:swaps/swaps.dart';

enum SwapRescueStatus { loading, ready, rescuing, success, error }

class SwapRescueState {
  final SwapRescueStatus status;
  final List<Wallet> wallets;
  final String? selectedWalletId;
  final String? error;

  const SwapRescueState({
    this.status = SwapRescueStatus.loading,
    this.wallets = const [],
    this.selectedWalletId,
    this.error,
  });

  bool get canRescue =>
      selectedWalletId != null &&
      status != SwapRescueStatus.rescuing &&
      status != SwapRescueStatus.success;

  SwapRescueState copyWith({
    SwapRescueStatus? status,
    List<Wallet>? wallets,
    String? selectedWalletId,
    String? error,
  }) {
    return SwapRescueState(
      status: status ?? this.status,
      wallets: wallets ?? this.wallets,
      selectedWalletId: selectedWalletId ?? this.selectedWalletId,
      error: error,
    );
  }
}

class SwapRescueCubit extends Cubit<SwapRescueState> {
  final RescueSwapUsecase _rescueSwapUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final RestoredSwap _restored;

  SwapRescueCubit({
    required this._rescueSwapUsecase,
    required this._getWalletsUsecase,
    required this._restored,
  }) : super(const SwapRescueState()) {
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    emit(state.copyWith(status: SwapRescueStatus.loading));
    try {
      // Funds land on the chain this swap acts on (claim destination or
      // refund return); only wallets on that chain are candidates.
      final wallets = await _getWalletsUsecase.execute(
        onlyBitcoin: !_restored.actsOnLiquid,
        onlyLiquid: _restored.actsOnLiquid,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: SwapRescueStatus.ready,
          wallets: wallets,
          selectedWalletId: wallets.isNotEmpty ? wallets.first.id : null,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: SwapRescueStatus.error, error: e.toString()));
    }
  }

  void selectWallet(String walletId) {
    emit(state.copyWith(selectedWalletId: walletId));
  }

  Future<void> rescue() async {
    final walletId = state.selectedWalletId;
    if (walletId == null) return;
    emit(state.copyWith(status: SwapRescueStatus.rescuing));
    try {
      final swap = await _rescueSwapUsecase.execute(
        restored: _restored,
        selectedWalletId: walletId,
      );
      log.fine(
        'SWAPS: rescue of ${swap.id} finished with status ${swap.status.name}',
      );
      if (isClosed) return;
      emit(state.copyWith(status: SwapRescueStatus.success));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: SwapRescueStatus.error, error: e.toString()));
    }
  }
}
