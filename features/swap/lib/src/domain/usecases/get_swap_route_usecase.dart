import 'package:swaps/swaps.dart' show SwapRoute, SwapRouting;

class GetSwapRouteUsecase {
  final SwapRouting _routing;

  const GetSwapRouteUsecase(this._routing);

  Future<SwapRoute> execute() => _routing.resolveRoute();
}
