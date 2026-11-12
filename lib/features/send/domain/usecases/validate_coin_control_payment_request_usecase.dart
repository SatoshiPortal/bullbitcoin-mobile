import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';

class ValidateCoinControlPaymentRequestUsecase {
  Result<void, SendFailure> execute({
    required Wallet wallet,
    required PaymentRequest paymentRequest,
    bool isSweep = true,
  }) {
    final isMatchingDestination = switch (paymentRequest) {
      // A BIP21 request carries its concrete network: compare it directly.
      // Its isTestnet getter refuses regtest, which detection produces.
      Bip21PaymentRequest(:final network, :final amountSat) =>
        network == wallet.network && (!isSweep || amountSat == null),
      // Legacy address requests only know testnet or not.
      BitcoinPaymentRequest(:final isTestnet) =>
        wallet.isBitcoin && !wallet.network.isMainnet == isTestnet,
      LiquidPaymentRequest(:final isTestnet) =>
        wallet.isLiquid && !wallet.network.isMainnet == isTestnet,
      _ => false,
    };
    if (!isMatchingDestination) {
      return const Err(SendInvalidPaymentRequestFailure());
    }
    return const Ok(null);
  }
}
