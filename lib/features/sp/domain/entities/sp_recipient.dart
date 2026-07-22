/// A send output. Domain mirror of the bwk `RecipientView` FFI union; the wire
/// type stays in `data/` behind `SpRecipientMapper`.
sealed class SpRecipient {
  const SpRecipient();

  String get address;
  BigInt get amountSat;
  bool get isMax;
}

/// A silent payment (sp1/tsp1) recipient. [label] is the bwk output label.
final class SpRecipientSp extends SpRecipient {
  @override
  final String address;
  @override
  final BigInt amountSat;
  @override
  final bool isMax;
  final int? label;

  const SpRecipientSp({
    required this.address,
    required this.amountSat,
    required this.isMax,
    this.label,
  });
}

/// A standard on-chain (bc1...) recipient.
final class SpRecipientStandard extends SpRecipient {
  @override
  final String address;
  @override
  final BigInt amountSat;
  @override
  final bool isMax;

  const SpRecipientStandard({
    required this.address,
    required this.amountSat,
    required this.isMax,
  });
}
