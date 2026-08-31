import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class WatchSwapProviderUnavailableAnnouncementUsecase {
  final SwapFacade _swapFacade;

  WatchSwapProviderUnavailableAnnouncementUsecase(this._swapFacade);

  Stream<bool> execute() => _swapFacade.watchSwapProviderUnavailable();
}
