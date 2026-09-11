import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';

class ValidateSweepPaymentRequestUsecase {
  Result<void, SendFailure> execute({
    required Wallet wallet,
    required PaymentRequest paymentRequest,
  }) {
    final isBitcoinDestination =
        paymentRequest is BitcoinPaymentRequest ||
        (paymentRequest is Bip21PaymentRequest &&
            paymentRequest.network.isBitcoin &&
            paymentRequest.amountSat == null);
    if (!wallet.isBitcoin ||
        !isBitcoinDestination ||
        wallet.isTestnet != paymentRequest.isTestnet) {
      return const Err(SendInvalidPaymentRequestFailure());
    }
    return const Ok(null);
  }
}
