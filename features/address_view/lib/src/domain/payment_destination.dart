enum PaymentDestinationType { bitcoin, liquid, lightningAddress }

/// A parsed destination accepted by the receiving flow's capabilities.
final class PaymentDestination {
  final String raw;
  final String address;
  final PaymentDestinationType type;
  final int? amountSat;
  final bool isLnurl;

  const PaymentDestination({
    required this.raw,
    required this.address,
    required this.type,
    this.amountSat,
    this.isLnurl = false,
  });
}
