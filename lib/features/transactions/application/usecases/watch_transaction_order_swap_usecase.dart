import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class WatchTransactionOrderSwapUsecase {
  final SwapFacade _swapFacade;

  const WatchTransactionOrderSwapUsecase(this._swapFacade);

  Stream<OrderSwapRecord> execute(String localId) =>
      _swapFacade.watchOrder(localId);
}
