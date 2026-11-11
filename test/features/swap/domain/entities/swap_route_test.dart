import 'package:bb_mobile/features/swap/domain/entities/swap_route.dart';
import 'package:boltz_swaps/boltz_swaps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SwapRoute.resolve', () {
    test('is Boltz only until the user turns the fallback on', () {
      expect(
        SwapRoute.resolve(
          exchangeFallbackEnabled: false,
          devModeEnabled: false,
          override: SwapRouteOverride.auto,
        ),
        SwapRoute.boltz,
      );
      expect(
        SwapRoute.resolve(
          exchangeFallbackEnabled: true,
          devModeEnabled: false,
          override: SwapRouteOverride.auto,
        ),
        SwapRoute.boltzWithExchangeFallback,
      );
    });

    test('ignores the override outside dev mode', () {
      expect(
        SwapRoute.resolve(
          exchangeFallbackEnabled: false,
          devModeEnabled: false,
          override: SwapRouteOverride.exchangeOnly,
        ),
        SwapRoute.boltz,
      );
    });

    test('pins the provider in dev mode', () {
      expect(
        SwapRoute.resolve(
          exchangeFallbackEnabled: true,
          devModeEnabled: true,
          override: SwapRouteOverride.boltzOnly,
        ),
        SwapRoute.boltz,
      );
      expect(
        SwapRoute.resolve(
          exchangeFallbackEnabled: false,
          devModeEnabled: true,
          override: SwapRouteOverride.exchangeOnly,
        ),
        SwapRoute.exchange,
      );
      expect(
        SwapRoute.resolve(
          exchangeFallbackEnabled: true,
          devModeEnabled: true,
          override: SwapRouteOverride.auto,
        ),
        SwapRoute.boltzWithExchangeFallback,
      );
    });
  });

  group('SwapRoute.fallsBackToExchangeAfter', () {
    const unavailable = SwapsBoltzUnavailableFailure();
    const outOfLimits = SwapsAmountOutOfLimitsFailure(minSat: 1, maxSat: 2);
    const rejected = SwapsBoltzRejectedFailure();
    const network = SwapsNetworkFailure();

    test('falls back only when Boltz is unavailable or out of limits', () {
      const route = SwapRoute.boltzWithExchangeFallback;
      expect(route.fallsBackToExchangeAfter(unavailable), isTrue);
      expect(route.fallsBackToExchangeAfter(outOfLimits), isTrue);
      expect(route.fallsBackToExchangeAfter(rejected), isFalse);
      expect(route.fallsBackToExchangeAfter(network), isFalse);
    });

    test('never falls back without the user opt-in', () {
      expect(SwapRoute.boltz.fallsBackToExchangeAfter(unavailable), isFalse);
      expect(SwapRoute.boltz.fallsBackToExchangeAfter(outOfLimits), isFalse);
    });
  });
}
