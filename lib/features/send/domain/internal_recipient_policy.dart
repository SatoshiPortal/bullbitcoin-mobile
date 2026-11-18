import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/wallet/public/recipient_wallet.dart';

import 'bitcoin_recipient_list_policy.dart';

/// Internal recipients are direct Bitcoin outputs on the primary network.
final class InternalRecipientPolicy {
  const InternalRecipientPolicy();

  Network? network(PaymentRequest? request) => switch (request) {
    BitcoinPaymentRequest(:final address)
        when address.toLowerCase().startsWith('bcrt1') =>
      Network.bitcoinRegtest,
    BitcoinPaymentRequest(:final isTestnet) =>
      isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet,
    Bip21PaymentRequest(:final network)
        when const BitcoinRecipientListPolicy().supports(request) =>
      network,
    _ => null,
  };

  bool permits(
    Wallet wallet,
    PaymentRequest? request, {
    String? fixedSourceWalletId,
  }) =>
      wallet.isBitcoin &&
      wallet.network == network(request) &&
      wallet.id != fixedSourceWalletId;
}
