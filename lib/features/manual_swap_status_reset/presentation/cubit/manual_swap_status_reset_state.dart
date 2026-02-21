part of 'manual_swap_status_reset_cubit.dart';

@freezed
sealed class ManualSwapStatusResetState with _$ManualSwapStatusResetState {
  const factory ManualSwapStatusResetState({
    String? swapId,
    Swap? swap,
    @Default(false) bool isLoading,
    String? errorMessage,
    String? successMessage,
  }) = _ManualSwapStatusResetState;
  const ManualSwapStatusResetState._();
}
