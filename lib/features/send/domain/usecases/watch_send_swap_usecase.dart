import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class WatchSendSwapUsecase {
  final SwapFacade _swapFacade;

  const WatchSendSwapUsecase(this._swapFacade);

  Stream<OrderSwapRecord> execute(String localId) =>
      _swapFacade.watchOrder(localId);
}
