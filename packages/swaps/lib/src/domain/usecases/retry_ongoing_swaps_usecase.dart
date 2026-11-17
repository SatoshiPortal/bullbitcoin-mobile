import 'package:swaps/src/domain/swap_watcher.dart';
import 'package:swaps/src/log.dart';

/// User-triggered "look now" over every ongoing swap: clears the backoff a
/// failed action left behind and sweeps at once, so a manual refresh never
/// waits out a retry delay.
class RetryOngoingSwapsUsecase {
  final SwapWatcher _swapWatcher;

  const RetryOngoingSwapsUsecase(this._swapWatcher);

  Future<void> execute() async {
    try {
      await _swapWatcher.restart();
    } catch (e) {
      swapsLog.warning('SWAPS: manual retry failed (${e.runtimeType})');
    }
  }
}
