part of 'swap_rescue_cubit.dart';

@freezed
abstract class SwapRescueState with _$SwapRescueState {
  const factory SwapRescueState({
    @Default(<Swap>[]) List<Swap> swaps,
    @Default(false) bool loading,
    @Default(false) bool actionLoading,
    String? error,
    String? successMessage,
  }) = _SwapRescueState;
}
