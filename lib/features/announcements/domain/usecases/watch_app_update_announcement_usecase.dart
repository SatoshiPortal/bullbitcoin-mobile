import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class WatchAppUpdateAnnouncementUsecase {
  final SwapFacade _swapFacade;

  WatchAppUpdateAnnouncementUsecase(this._swapFacade);

  Stream<bool> execute() => _swapFacade.watchAppUpdateRequired();
}
