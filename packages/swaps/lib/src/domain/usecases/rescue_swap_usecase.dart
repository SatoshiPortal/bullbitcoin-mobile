import 'package:swaps/src/log.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/restored_swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/swap_repository.dart';
import 'package:swaps/src/domain/swap_watcher.dart';

/// Re-materialises a restored swap and immediately hands it to the watcher
/// so the pending claim or refund is driven without waiting for the next
/// launch.
class RescueSwapUsecase {
  final SwapRepository _swapRepository;
  final SwapWatcher _swapWatcher;

  RescueSwapUsecase({
    required this._swapRepository,
    required this._swapWatcher,
  });

  Future<Result<Swap, SwapsFailure>> execute({
    required RestoredSwap restored,
    required String selectedWalletId,
  }) async {
    try {
      final swap = await _swapRepository.rescue(
        restored,
        walletId: selectedWalletId,
      );
      await _swapWatcher.processSwap(swap);
      return Ok(await _swapRepository.get(swap.id));
    } catch (e) {
      swapsLog.warning('SWAPS: rescue failed: $e');
      return Err(classifySwapsFailure(e));
    }
  }
}
