import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_watcher.dart';

/// Receives a Lightning payment into a Bitcoin wallet through Boltz.
class CreateLightningToBitcoinSwapUsecase {
  final BoltzSwaps _boltz;
  final SwapWatcher _swapWatcher;

  const CreateLightningToBitcoinSwapUsecase(this._boltz, this._swapWatcher);

  Future<Result<LnReceiveSwap, SwapsFailure>> execute({
    required String walletId,
    required int amountSat,
    String? description,
  }) async {
    final created = await _boltz.createLightningToBitcoinSwap(
      walletId: walletId,
      amountSat: amountSat,
      description: description,
    );
    if (created case Ok()) _swapWatcher.ensureRunning();
    return created;
  }
}
