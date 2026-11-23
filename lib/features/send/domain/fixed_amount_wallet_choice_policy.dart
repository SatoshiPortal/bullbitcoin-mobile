import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/features/wallet/public/recipient_wallet.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';

/// A fixed request must not silently choose between eligible direct wallets.
final class FixedAmountWalletChoicePolicy {
  const FixedAmountWalletChoicePolicy();

  bool requiresChoice({
    required PaymentRequest request,
    required Iterable<Wallet> wallets,
    required bool hasFixedSource,
  }) {
    return !hasFixedSource && eligibleWallets(request, wallets).length >= 2;
  }

  List<Wallet> eligibleWallets(
    PaymentRequest request,
    Iterable<Wallet> wallets,
  ) {
    if (request is! Bip21PaymentRequest) return const [];
    final amount = request.amountSat;
    if (amount == null || amount <= 0) return const [];
    final eligible = <String, Wallet>{};
    for (final wallet in wallets) {
      final balance = wallet.balanceSat;
      if (wallet.network.shared == request.network &&
          !wallet.isWatchOnly &&
          balance != null &&
          balance > BigInt.from(amount)) {
        eligible[wallet.id] = wallet;
      }
    }
    return eligible.values.toList();
  }
}
