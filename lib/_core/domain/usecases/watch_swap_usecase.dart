import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/services/swap_watcher_service.dart';

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

class WatchSwapException implements Exception {
  final String message;

  WatchSwapException(this.message);
}
