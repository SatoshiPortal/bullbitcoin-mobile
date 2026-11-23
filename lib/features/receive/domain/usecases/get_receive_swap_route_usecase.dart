import 'package:receive/receive.dart';

import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class GetReceiveSwapRouteUsecase {
  final SwapFacade _swapFacade;

  const GetReceiveSwapRouteUsecase(this._swapFacade);

  static ReceiveLightningLimits limitsFor({
    SwapRoute? route,
    int? minimumSat,
    int? maximumSat,
  }) => ReceiveLightningLimits(
    requiresBounds: route == SwapRoute.boltz,
    minimumSat: minimumSat,
    maximumSat: maximumSat,
  );

  Future<SwapRoute> execute() => _swapFacade.getRoute();
}
