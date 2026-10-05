import 'package:bb_mobile/core/utils/lightning.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

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
    try {
      final invoice = await invoiceFromLnAddress(
        lnAddress: lightningAddress,
        amountSat: amountSat,
      );
      final request = await PaymentRequest.parse(invoice);
      if (request is! Bolt11PaymentRequest || request.amountSat != amountSat) {
        return const Err(
          SendInvalidPaymentRequestFailure(
            logMessage: 'Lightning address returned an invalid invoice',
          ),
        );
      }
      return Ok(request);
    } catch (error, st) {
      log.warning(
        'Could not resolve the lightning address',
        error: error,
        trace: st,
      );
      return Err(
        SendInvalidPaymentRequestFailure(logMessage: error.toString()),
      );
    }
  }
}
