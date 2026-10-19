import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';

class ValidateCoinControlPaymentRequestUsecase {
  Result<void, SendFailure> execute({
    required Wallet wallet,
    required PaymentRequest paymentRequest,
    bool isSweep = true,
  }) {
    final isMatchingDestination =
        (wallet.isBitcoin && paymentRequest is BitcoinPaymentRequest) ||
        (wallet.isLiquid && paymentRequest is LiquidPaymentRequest) ||
        (paymentRequest is Bip21PaymentRequest &&
            paymentRequest.network == wallet.network &&
            (!isSweep || paymentRequest.amountSat == null));
    if (!isMatchingDestination ||
        wallet.isTestnet != paymentRequest.isTestnet) {
      return const Err(SendInvalidPaymentRequestFailure());
    }
    return const Ok(null);
  }
}
