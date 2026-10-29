import '../../domain/settings_failure.dart';
import '../../domain/usecases/rescue_settings_swap_usecase.dart';
import '../../domain/usecases/load_settings_swap_wallets_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/rescue_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SwapRescueStatus { loading, ready, rescuing, success, error }

class SwapRescueState {
  final SwapRescueStatus status;
  final List<Wallet> wallets;
  final String? selectedWalletId;
  final SettingsFailure? failure;

  const SwapRescueState({
    this.status = SwapRescueStatus.loading,
    this.wallets = const [],
    this.selectedWalletId,
    this.failure,
  });

  bool get canRescue =>
      selectedWalletId != null &&
      status != SwapRescueStatus.rescuing &&
      status != SwapRescueStatus.success;

  SwapRescueState copyWith({
    SwapRescueStatus? status,
    List<Wallet>? wallets,
    String? selectedWalletId,
    SettingsFailure? failure,
  }) {
    return SwapRescueState(
      status: status ?? this.status,
      wallets: wallets ?? this.wallets,
      selectedWalletId: selectedWalletId ?? this.selectedWalletId,
      failure: failure,
    );
  }
}

class SwapRescueCubit extends Cubit<SwapRescueState> {
  final RescueSwapUsecase _rescueSwapUsecase;
  late final _rescue = RescueSettingsSwapUsecase(rescue: _rescueSwapUsecase);
  late final _wallets = LoadSettingsSwapWalletsUsecase(
    rescue: _rescueSwapUsecase,
  );
  final RestoredSwap _restored;

  SwapRescueCubit({required this._rescueSwapUsecase, required this._restored})
    : super(const SwapRescueState()) {
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    emit(state.copyWith(status: SwapRescueStatus.loading));
    final result = await _wallets.execute(_restored);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: SwapRescueStatus.ready,
            wallets: value,
            selectedWalletId: value.isEmpty ? null : value.first.id,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: SwapRescueStatus.error, failure: failure));
    }
  }

  void selectWallet(String walletId) {
    emit(state.copyWith(selectedWalletId: walletId));
  }

  Future<void> rescue() async {
    final walletId = state.selectedWalletId;
    if (walletId == null) return;
    emit(state.copyWith(status: SwapRescueStatus.rescuing));
    final result = await _rescue.execute(
      restored: _restored,
      selectedWalletId: walletId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(status: SwapRescueStatus.success));
      case Err(:final failure):
        emit(state.copyWith(status: SwapRescueStatus.error, failure: failure));
    }
  }
}
