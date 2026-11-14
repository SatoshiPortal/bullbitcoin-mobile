import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:primitives/primitives.dart' show Ok, Err;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SwapRescueStatus { loading, ready, rescuing, success, error }

class SwapRescueState {
  final SwapRescueStatus status;
  final List<Wallet> wallets;
  final String? selectedWalletId;
  final SwapFailure? error;

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
    SwapFailure? error,
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
  final RestoredSwap _restored;

  SwapRescueCubit({required this._rescueSwapUsecase, required this._restored})
    : super(const SwapRescueState()) {
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    emit(state.copyWith(status: SwapRescueStatus.loading));
    final result = await _rescueSwapUsecase.candidateWallets(_restored);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: SwapRescueStatus.ready,
            wallets: value,
            selectedWalletId: value.firstOrNull?.id,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: SwapRescueStatus.error, error: failure));
    }
  }

  void selectWallet(String walletId) {
    emit(state.copyWith(selectedWalletId: walletId));
  }

  Future<void> rescue() async {
    final walletId = state.selectedWalletId;
    if (walletId == null) return;
    emit(state.copyWith(status: SwapRescueStatus.rescuing));
    final result = await _rescueSwapUsecase.execute(
      restored: _restored,
      selectedWalletId: walletId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(status: SwapRescueStatus.success));
      case Err(:final failure):
        emit(state.copyWith(status: SwapRescueStatus.error, error: failure));
    }
  }
}
