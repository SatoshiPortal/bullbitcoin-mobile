import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:boltz_swaps/boltz_swaps.dart';
import 'package:meta/meta.dart';

/// Creates (or reuses the pending) Boltz submarine swap that pays [invoice]
/// from [wallet]. Returns the engine's failure untranslated so the caller can
/// decide on the exchange fallback before mapping it for display.
class CreateBoltzSendSwapUsecase {
  final CreateLightningSendSwapUsecase _createLightningSendSwapUsecase;

  const CreateBoltzSendSwapUsecase(this._createLightningSendSwapUsecase);

  @useResult
  Future<Result<LnSendSwap, SwapsFailure>> execute({
    required Wallet wallet,
    required Bolt11PaymentRequest invoice,
  }) => _createLightningSendSwapUsecase.execute(
    walletId: wallet.id,
    invoice: invoice.invoice,
    invoiceAmountSat: invoice.amountSat,
    fromLiquid: wallet.network.isLiquid,
  );
}
