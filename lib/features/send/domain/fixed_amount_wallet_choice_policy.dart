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
    return switch (request) {
      Bip21PaymentRequest(:final network, :final amountSat?)
          when amountSat > 0 =>
        _funding(
          wallets,
          amountSat,
          (wallet) => wallet.network.shared == network && !wallet.isWatchOnly,
        ),
      // An invoice is paid through a swap, which only a local signer can fund,
      // from either chain.
      Bolt11PaymentRequest(:final amountSat, :final isTestnet)
          when amountSat > 0 =>
        _funding(
          wallets,
          amountSat,
          (wallet) =>
              wallet.signsLocally && !wallet.network.isMainnet == isTestnet,
        ),
      _ => const [],
    };
  }

  List<Wallet> _funding(
    Iterable<Wallet> wallets,
    int amountSat,
    bool Function(Wallet wallet) isCandidate,
  ) {
    final eligible = <String, Wallet>{};
    for (final wallet in wallets) {
      final balance = wallet.balanceSat;
      if (isCandidate(wallet) &&
          balance != null &&
          balance > BigInt.from(amountSat)) {
        eligible[wallet.id] = wallet;
      }
    }
    return eligible.values.toList();
  }
}
