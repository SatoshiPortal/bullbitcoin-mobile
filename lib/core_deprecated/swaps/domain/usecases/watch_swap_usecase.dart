import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/swaps/data/services/swap_watcher.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';

class WatchSwapUsecase {
  final SwapWatcherService _watcher;

  WatchSwapUsecase({required SwapWatcherService watcherService})
    : _watcher = watcherService;

  Stream<Swap> execute(String swapId) {
    try {
      return _watcher.swapStream.where((s) {
        log.info(
          '[WatchSwapUsecase] swapId: ${s.id}, swap status: ${s.status}',
        );
        return s.id == swapId;
      });
    } catch (e) {
      throw WatchSwapException(e.toString());
    }
  }
}

class WatchSwapException extends BullException {
  WatchSwapException(super.message);
}
