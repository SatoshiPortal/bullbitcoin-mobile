import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_watcher.dart';

/// Polls every ongoing swap's status over REST and executes any pending
/// claim/refund/coop-close to completion. Used by the background task, which
/// has no long-lived websocket: poll, act, return.
class ProcessOngoingSwapsUsecase {
  final SwapWatcherService _watcher;

  ProcessOngoingSwapsUsecase({required SwapWatcherService watcherService})
    : _watcher = watcherService;

  Future<void> execute() async {
    try {
      await _watcher.processOngoingSwapsOnce();
    } catch (e) {
      throw ProcessOngoingSwapsException(e.toString());
    }
  }
}

class ProcessOngoingSwapsException extends BullException {
  ProcessOngoingSwapsException(super.message);
}
