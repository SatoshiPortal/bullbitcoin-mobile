import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:swaps/swaps.dart';
import 'package:meta/meta.dart';

/// Creates the Boltz reverse swap whose invoice pays [amountSat] into
/// [wallet], on the pair of the wallet's chain. Returns the engine's failure
/// untranslated so the caller can decide on the exchange fallback before
/// mapping it for display.
class CreateBoltzReceiveSwapUsecase {
  final BoltzSwaps _boltz;
  final SwapWatcher _swapWatcher;

  const CreateBoltzReceiveSwapUsecase(this._boltz, this._swapWatcher);

  @useResult
  Future<Result<LnReceiveSwap, SwapsFailure>> execute({
    required Wallet wallet,
    required int amountSat,
    String? note,
  }) async {
    final description = note == null || note.isEmpty ? null : note;
    final created = wallet.network.isLiquid
        ? await _boltz.createLightningToLiquidSwap(
            walletId: wallet.id,
            amountSat: amountSat,
            description: description,
          )
        : await _boltz.createLightningToBitcoinSwap(
            walletId: wallet.id,
            amountSat: amountSat,
            description: description,
          );
    if (created case Ok()) _swapWatcher.ensureRunning();
    return created;
  }
}
