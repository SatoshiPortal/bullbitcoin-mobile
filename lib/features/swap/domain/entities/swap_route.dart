import 'package:boltz_swaps/boltz_swaps.dart';

/// A developer's pin on the swap provider. Ignored outside dev mode.
enum SwapRouteOverride { auto, boltzOnly, exchangeOnly }

/// The stored swap route choices, as the swap settings page edits them.
typedef SwapRouteSettings = ({
  bool exchangeFallbackEnabled,
  SwapRouteOverride override,
  bool devModeEnabled,
});

/// Which provider creates a swap. Boltz is the default. The exchange takes
/// over only when the user turned the fallback on, and only after Boltz
/// failed before anything was created.
enum SwapRoute {
  boltz,
  boltzWithExchangeFallback,
  exchange;

  factory SwapRoute.resolve({
    required bool exchangeFallbackEnabled,
    required bool devModeEnabled,
    required SwapRouteOverride override,
  }) {
    if (devModeEnabled) {
      switch (override) {
        case SwapRouteOverride.boltzOnly:
          return SwapRoute.boltz;
        case SwapRouteOverride.exchangeOnly:
          return SwapRoute.exchange;
        case SwapRouteOverride.auto:
          break;
      }
    }
    return exchangeFallbackEnabled
        ? SwapRoute.boltzWithExchangeFallback
        : SwapRoute.boltz;
  }

  bool get startsWithBoltz => this != SwapRoute.exchange;

  bool fallsBackToExchangeAfter(SwapsFailure failure) =>
      this == SwapRoute.boltzWithExchangeFallback &&
      switch (failure) {
        SwapsBoltzUnavailableFailure() ||
        SwapsAmountOutOfLimitsFailure() => true,
        _ => false,
      };
}
