import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:swaps/swaps.dart';
import 'package:meta/meta.dart';

/// Creates (or reuses the pending) Boltz submarine swap that pays [invoice]
/// from [wallet], on the pair of the wallet's chain. Returns the engine's
/// failure untranslated so the caller can decide on the exchange fallback
/// before mapping it for display.
class CreateBoltzSendSwapUsecase {
  final BoltzSwaps _boltz;
  final SwapWatcher _swapWatcher;

  const CreateBoltzSendSwapUsecase(this._boltz, this._swapWatcher);

  @useResult
  Future<Result<LnSendSwap, SwapsFailure>> execute({
    required Wallet wallet,
    required Bolt11PaymentRequest invoice,
  }) async {
    final created = wallet.network.isLiquid
        ? await _boltz.createLiquidToLightningSwap(
            walletId: wallet.id,
            invoice: invoice.invoice,
          )
        : await _boltz.createBitcoinToLightningSwap(
            walletId: wallet.id,
            invoice: invoice.invoice,
          );
    if (created case Ok()) _swapWatcher.ensureRunning();
    return created;
  }
}
