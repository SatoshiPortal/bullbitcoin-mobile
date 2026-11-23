import 'package:receive/receive.dart';

import 'package:swaps/swaps.dart' show SwapRoute, SwapRouting;

class GetReceiveSwapRouteUsecase {
  final SwapRouting _routing;

  const GetReceiveSwapRouteUsecase(this._routing);

  static ReceiveLightningLimits limitsFor({
    SwapRoute? route,
    int? minimumSat,
    int? maximumSat,
  }) => ReceiveLightningLimits(
    requiresBounds: route == SwapRoute.boltz,
    minimumSat: minimumSat,
    maximumSat: maximumSat,
  );

  Future<SwapRoute> execute() => _routing.resolveRoute();
}
