import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class RefreshWalletOrderSwapsUsecase {
  final SwapFacade _swapFacade;

  const RefreshWalletOrderSwapsUsecase(this._swapFacade);

  Future<bool> execute() async =>
      (await _swapFacade.refreshOrders()) is Ok<void, SwapFailure>;
}
