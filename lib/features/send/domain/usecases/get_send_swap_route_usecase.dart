import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class GetSendSwapRouteUsecase {
  final SwapFacade _swapFacade;

  const GetSendSwapRouteUsecase(this._swapFacade);

  Future<SwapRoute> execute() => _swapFacade.getRoute();
}
