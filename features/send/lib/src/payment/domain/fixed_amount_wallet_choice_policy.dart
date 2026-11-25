import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/domain/send_source.dart';

/// A fixed request must not silently choose between eligible direct wallets.
final class FixedAmountWalletChoicePolicy {
  const FixedAmountWalletChoicePolicy();

  bool requiresChoice({
    required PaymentRequest request,
    required Iterable<SendSource> wallets,
    required bool hasFixedSource,
  }) {
    return !hasFixedSource && eligibleWallets(request, wallets).length >= 2;
  }

  List<SendSource> eligibleWallets(
    PaymentRequest request,
    Iterable<SendSource> wallets,
  ) {
    if (request is! Bip21PaymentRequest) return const [];
    final amount = request.amountSat;
    if (amount == null || amount <= 0) return const [];
    final eligible = <String, SendSource>{};
    for (final wallet in wallets) {
      final balance = wallet.balanceSat;
      if (wallet.network == request.network &&
          !wallet.isWatchOnly &&
          balance != null &&
          balance > BigInt.from(amount)) {
        eligible[wallet.id] = wallet;
      }
    }
    return eligible.values.toList();
  }
}
