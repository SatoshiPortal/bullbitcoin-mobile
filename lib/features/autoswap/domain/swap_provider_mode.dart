import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';

/// Which swap provider handles new swap orders.
///
/// Global, not per-swap: once a Boltz server URL is configured the user has
/// switched to Boltz and Exchange is abandoned for new orders. In-flight
/// Exchange orders keep being watched regardless of the mode.
enum SwapProviderMode { exchange, boltz }

extension SwapProviderModeResolver on AutoSwap {
  /// A configured Boltz URL means the user already switched to Boltz.
  SwapProviderMode get providerMode =>
      boltzFallbackUrl != null ? SwapProviderMode.boltz : SwapProviderMode.exchange;
}
