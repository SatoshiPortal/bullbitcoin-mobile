import 'package:bb_mobile/core/swaps/data/services/swap_watcher.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class RestartSwapWatcherUsecase {
  final SwapWatcherService? _swapWatcherService;

  const RestartSwapWatcherUsecase({
    required SwapWatcherService swapWatcherService,
  }) : _swapWatcherService = swapWatcherService;

  Future<void> execute() async {
    if (_swapWatcherService != null) {
      try {
        await _swapWatcherService.restartWatcherWithOngoingSwaps();
      } catch (e) {
        log.severe('Error restarting swap watcher: $e');
      }
    }
    log.info('Restarted swap watcher');
  }
}
