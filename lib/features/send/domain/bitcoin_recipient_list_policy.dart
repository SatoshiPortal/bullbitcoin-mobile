import 'package:bb_mobile/core/utils/payment_request.dart';

typedef BitcoinRecipientCandidate = ({
  bool isValid,
  bool receivesRemainder,
  int amountSat,
});

final class BitcoinRecipientListPolicy {
  const BitcoinRecipientListPolicy();

  bool supports(PaymentRequest? request, {bool allowAmount = false}) =>
      switch (request) {
        BitcoinPaymentRequest() => true,
        Bip21PaymentRequest(:final network, :final amountSat) =>
          network.isBitcoin &&
              (amountSat == null || (allowAmount && amountSat > 0)),
        _ => false,
      };

  bool? networkIsTestnet(PaymentRequest? request) => switch (request) {
    BitcoinPaymentRequest(:final isTestnet) => isTestnet,
    Bip21PaymentRequest(:final network) when network.isBitcoin =>
      network.isTestnet,
    _ => null,
  };

  bool shouldRetainAdditionalRecipients({
    required int recipientCount,
    required PaymentRequest? nextRequest,
    required bool? currentNetworkIsTestnet,
  }) {
    if (recipientCount <= 1) return false;
    if (nextRequest == null) return true;
    return supports(nextRequest) &&
        networkIsTestnet(nextRequest) == currentNetworkIsTestnet;
  }

  String? compatibleAdditionalAddress({
    required PaymentRequest request,
    required bool? primaryNetworkIsTestnet,
    required bool isSweep,
  }) {
    if (!supports(request, allowAmount: !isSweep) ||
        networkIsTestnet(request) != primaryNetworkIsTestnet) {
      return null;
    }
    return switch (request) {
      BitcoinPaymentRequest(:final address) => address,
      Bip21PaymentRequest(:final address) => address,
      _ => null,
    };
  }

  bool hasValidRecipients({
    required Iterable<BitcoinRecipientCandidate> recipients,
    required bool isSweep,
  }) {
    var recipientCount = 0;
    var remainderCount = 0;
    for (final recipient in recipients) {
      recipientCount++;
      if (!recipient.isValid) return false;
      if (recipient.receivesRemainder) {
        remainderCount++;
      } else if (recipient.amountSat <= 0) {
        return false;
      }
    }
    return recipientCount > 0 &&
        remainderCount <= 1 &&
        (!isSweep || remainderCount == 1);
  }
}
