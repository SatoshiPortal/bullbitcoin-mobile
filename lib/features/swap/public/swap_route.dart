export '../ui/swap_router.dart' show SwapRoute;

final class SwapRouteArgs {
  final String externalAddress;
  final bool isLiquidAddress;

  const SwapRouteArgs({
    required this.externalAddress,
    required this.isLiquidAddress,
  });
}
