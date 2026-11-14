import 'package:boltz_swaps/boltz_swaps.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' show Ok, Err;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SwapRescueStatus { loading, ready, rescuing, success, error }

class SwapRescueState {
  final SwapRescueStatus status;
  final List<Wallet> wallets;
  final String? selectedWalletId;
  final SwapsFailure? error;

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
    SwapsFailure? error,
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
    final result = await _getWalletsUsecase.execute(
      onlyBitcoin: !_restored.actsOnLiquid,
      onlyLiquid: _restored.actsOnLiquid,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: SwapRescueStatus.ready,
            wallets: value,
            selectedWalletId: value.isNotEmpty ? value.first.id : null,
          ),
        );
      case Err(:final failure):
        log.warning(
          'SWAPS: rescue wallets read failed: ${failure.runtimeType}',
        );
        emit(
          state.copyWith(
            status: SwapRescueStatus.error,
            error: SwapsUnexpectedFailure(
              'wallets read failed: ${failure.runtimeType}',
            ),
          ),
        );
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
      case Ok(:final value):
        log.fine(
          'SWAPS: rescue of ${value.id} finished with status '
          '${value.status.name}',
        );
        emit(state.copyWith(status: SwapRescueStatus.success));
      case Err(:final failure):
        emit(state.copyWith(status: SwapRescueStatus.error, error: failure));
    }
  }
}
