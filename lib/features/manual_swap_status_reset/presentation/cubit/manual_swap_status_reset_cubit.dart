import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/manual_swap_status_reset/domain/usecases/manual_swap_status_reset_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'manual_swap_status_reset_state.dart';
part 'manual_swap_status_reset_cubit.freezed.dart';

class ManualSwapStatusResetCubit extends Cubit<ManualSwapStatusResetState> {
  final ManualSwapStatusResetUsecase _manualSwapStatusResetUsecase;

  ManualSwapStatusResetCubit({
    required ManualSwapStatusResetUsecase manualSwapStatusResetUsecase,
  }) : _manualSwapStatusResetUsecase = manualSwapStatusResetUsecase,
       super(const ManualSwapStatusResetState());

  Future<void> findAndUpdateSwapStatusById(String swapId) async {
    final id = swapId.trim();
    if (id.isEmpty) return;
    emit(state.copyWith(
      swapId: id,
      swap: null,
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    ));
    try {
      final swap = await _manualSwapStatusResetUsecase.execute(id);
      if (swap == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Swap not found',
        ));
      } else {
        emit(state.copyWith(
          swap: swap,
          isLoading: false,
          successMessage: 'Status updated to paid',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Swap not found: ${e.toString()}',
      ));
    }
  }

  void updateSwapId(String swapId) {
    emit(state.copyWith(swapId: swapId));
  }

  void clearMessages() {
    emit(state.copyWith(errorMessage: null, successMessage: null));
  }
}
