import 'enums/receive_network_type.dart';
import 'receive_amount_conversion.dart';

/// A canonical request candidate. Representation-only edits never change it.
final class ReceiveLiveAmount {
  const ReceiveLiveAmount({
    required this.network,
    required this.walletId,
    required this.canonicalAmount,
    required this.admitted,
    this.conversion,
  });
  final ReceiveNetworkType? network;
  final String? walletId;
  final String canonicalAmount;
  final bool admitted;
  final ReceiveAmountConversion? conversion;

  bool get canUpdate =>
      admitted &&
      walletId != null &&
      (network == ReceiveNetworkType.bitcoin ||
          network == ReceiveNetworkType.liquid);

  bool stillMatches(ReceiveLiveAmount current) =>
      canUpdate &&
      current.canUpdate &&
      network == current.network &&
      walletId == current.walletId &&
      canonicalAmount == current.canonicalAmount &&
      conversion == current.conversion;
}
