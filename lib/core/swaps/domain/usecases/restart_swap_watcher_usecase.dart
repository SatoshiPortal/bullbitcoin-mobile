import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
import 'package:flutter/foundation.dart';

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
        debugPrint('Error restarting swap watcher: $e');
      }
    }
    debugPrint('Restarted swap watcher');
  }
}
