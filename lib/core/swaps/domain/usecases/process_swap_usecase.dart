import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';

class ProcessSwapUsecase {
  final SwapWatcherService _watcher;

  ProcessSwapUsecase({required SwapWatcherService watcherService})
    : _watcher = watcherService;

  Future<void> execute(Swap swap) async {
    try {
      await _watcher.processSwap(swap);
    } catch (e) {
      throw ProcessSwapException(e.toString());
    }
  }
}

class ProcessSwapException implements Exception {
  final String message;

  ProcessSwapException(this.message);
}
