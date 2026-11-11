import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class GetReceiveSwapRouteUsecase {
  final SwapFacade _swapFacade;

  const GetReceiveSwapRouteUsecase(this._swapFacade);

  Future<SwapRoute> execute() => _swapFacade.getRoute();
}
