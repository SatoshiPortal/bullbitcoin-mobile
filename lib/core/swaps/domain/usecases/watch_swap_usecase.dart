import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_watcher.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class WatchSwapUsecase {
  final SwapWatcherService _watcher;

  WatchSwapUsecase({required SwapWatcherService watcherService})
    : _watcher = watcherService;

  Stream<Swap> execute(String swapId) {
    try {
      return _watcher.swapStream.where((s) => s.id == swapId);
    } catch (e) {
      throw WatchSwapException(e.toString());
    }
  }
}

class WatchSwapException extends BullException {
  WatchSwapException(super.message);
}
