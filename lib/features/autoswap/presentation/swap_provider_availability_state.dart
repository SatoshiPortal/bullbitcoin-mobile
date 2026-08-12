part of 'swap_provider_availability_cubit.dart';

@freezed
abstract class SwapProviderAvailabilityState
    with _$SwapProviderAvailabilityState {
  const factory SwapProviderAvailabilityState({
    @Default(SwapProviderMode.exchange) SwapProviderMode mode,
    @Default(false) bool checking,
    @Default(false) bool exchangeUnavailable,
  }) = _SwapProviderAvailabilityState;
}
