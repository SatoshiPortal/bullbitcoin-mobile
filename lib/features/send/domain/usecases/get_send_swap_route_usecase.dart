import 'package:swaps/swaps.dart' show SwapRoute, SwapRouting;

class GetSendSwapRouteUsecase {
  final SwapRouting _routing;

  const GetSendSwapRouteUsecase(this._routing);

  Future<SwapRoute> execute() => _routing.resolveRoute();
}
