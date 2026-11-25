import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/lightning_address.dart';
import 'package:satoshifier/payment_request.dart';

import '../send_failure.dart';

class ResolveLightningAddressUsecase {
  const ResolveLightningAddressUsecase();

  @useResult
  Future<Result<Bolt11PaymentRequest, SendFailure>> execute({
    required String lightningAddress,
    required int amountSat,
  }) async {
    if (amountSat <= 0) {
      return const Err(SendInvoiceAmountRequiredFailure());
    }
    return (await resolveLightningAddress(
      lightningAddress,
      Sats.fromInt(amountSat),
    )).mapErr(
      (failure) => SendInvalidPaymentRequestFailure(
        logMessage: failure.runtimeType.toString(),
      ),
    );
  }
}
