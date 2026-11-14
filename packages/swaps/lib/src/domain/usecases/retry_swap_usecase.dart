import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_watcher.dart';

/// User-triggered "retry now" for a swap whose claim or refund never
/// landed: the script path only, without the provider, queued behind any
/// action the watcher is already running for the swap.
class RetrySwapUsecase {
  final SwapWatcher _swapWatcher;

  const RetrySwapUsecase(this._swapWatcher);

  Future<Result<Swap, SwapsFailure>> execute({required Swap swap}) =>
      _swapWatcher.retry(swap);
}
