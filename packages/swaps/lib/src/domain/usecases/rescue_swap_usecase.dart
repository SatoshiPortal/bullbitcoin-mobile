import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/restored_swap.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_resolver.dart';
import 'package:swaps/src/domain/swap_store.dart';
import 'package:swaps/src/domain/swap_watcher.dart';

/// Re-materialises a restored swap and immediately hands it to the watcher
/// so the pending claim or refund is driven without waiting for the next
/// launch.
class RescueSwapUsecase {
  final SwapResolver _resolver;
  final SwapStore _store;
  final SwapWatcher _swapWatcher;

  const RescueSwapUsecase(this._resolver, this._store, this._swapWatcher);

  Future<Result<Swap, SwapsFailure>> execute({
    required RestoredSwap restored,
    required String selectedWalletId,
  }) async {
    final rescued = await _resolver.rescue(
      restored,
      walletId: selectedWalletId,
    );
    final Swap swap;
    switch (rescued) {
      case Ok(:final value):
        swap = value;
      case Err():
        return rescued;
    }
    _swapWatcher.ensureRunning();
    await _swapWatcher.processSwap(swap);
    return _store.get(swap.id);
  }
}
