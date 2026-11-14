import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_watcher.dart';

/// Moves Liquid bitcoin to Bitcoin through a Boltz chain swap.
class CreateLiquidToBitcoinSwapUsecase {
  final BoltzSwaps _boltz;
  final SwapWatcher _swapWatcher;

  const CreateLiquidToBitcoinSwapUsecase(this._boltz, this._swapWatcher);

  Future<Result<ChainSwap, SwapsFailure>> execute({
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  }) async {
    final created = await _boltz.createLiquidToBitcoinSwap(
      sendWalletId: sendWalletId,
      amountSat: amountSat,
      destination: destination,
    );
    if (created case Ok()) _swapWatcher.ensureRunning();
    return created;
  }
}
