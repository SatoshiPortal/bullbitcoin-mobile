import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_watcher.dart';

/// Moves bitcoin to Liquid through a Boltz chain swap.
class CreateBitcoinToLiquidSwapUsecase {
  final BoltzSwaps _boltz;
  final SwapWatcher _swapWatcher;

  const CreateBitcoinToLiquidSwapUsecase(this._boltz, this._swapWatcher);

  Future<Result<ChainSwap, SwapsFailure>> execute({
    required String sendWalletId,
    required int amountSat,
    required ChainSwapDestination destination,
  }) async {
    final created = await _boltz.createBitcoinToLiquidSwap(
      sendWalletId: sendWalletId,
      amountSat: amountSat,
      destination: destination,
    );
    if (created case Ok()) _swapWatcher.ensureRunning();
    return created;
  }
}
