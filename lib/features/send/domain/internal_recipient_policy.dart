import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/features/wallet/public/recipient_wallet.dart'
    show Wallet;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

/// Internal recipients are direct Bitcoin outputs on the primary network.
final class InternalRecipientPolicy {
  const InternalRecipientPolicy();

  BitcoinNetwork? network(PaymentRequest? request) => switch (request) {
    BitcoinPaymentRequest(:final address)
        when address.toLowerCase().startsWith('bcrt1') =>
      BitcoinNetwork.regtest,
    BitcoinPaymentRequest(:final isTestnet) =>
      isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet,
    Bip21PaymentRequest(
      network: final BitcoinNetwork network,
      amountSat: null,
    ) =>
      network,
    _ => null,
  };

  bool permits(
    Wallet wallet,
    PaymentRequest? request, {
    String? fixedSourceWalletId,
  }) =>
      wallet.isBitcoin &&
      wallet.network.shared == network(request) &&
      wallet.id != fixedSourceWalletId;
}
