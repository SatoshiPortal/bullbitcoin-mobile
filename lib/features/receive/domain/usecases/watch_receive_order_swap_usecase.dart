import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class WatchReceiveOrderSwapUsecase {
  final SwapFacade _swapFacade;

  const WatchReceiveOrderSwapUsecase(this._swapFacade);

  Stream<OrderSwapRecord> execute(String localId) =>
      _swapFacade.watchOrder(localId);
}
