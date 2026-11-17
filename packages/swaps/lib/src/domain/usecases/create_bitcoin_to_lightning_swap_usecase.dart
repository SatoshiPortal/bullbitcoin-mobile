import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_watcher.dart';

/// Pays a Lightning invoice from a Bitcoin wallet through Boltz.
class CreateBitcoinToLightningSwapUsecase {
  final BoltzSwaps _boltz;
  final SwapWatcher _swapWatcher;

  const CreateBitcoinToLightningSwapUsecase(this._boltz, this._swapWatcher);

  Future<Result<LnSendSwap, SwapsFailure>> execute({
    required String walletId,
    required String invoice,
  }) async {
    final created = await _boltz.createBitcoinToLightningSwap(
      walletId: walletId,
      invoice: invoice,
    );
    if (created case Ok()) _swapWatcher.ensureRunning();
    return created;
  }
}
