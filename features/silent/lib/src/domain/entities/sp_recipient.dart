import 'package:silent/src/domain/entities/sp_address.dart';
import 'package:primitives/primitives.dart';

/// A send output. Domain mirror of the bwk `RecipientView` FFI union; the wire
/// type stays in `data/` behind `SpRecipientMapper`.
sealed class SilentRecipient {
  const SilentRecipient();

  SilentAddress get address;
  Sats get amountSat;
  bool get isMax;
}

/// A silent payment (sp1/tsp1) recipient. [label] is the bwk output label.
final class SilentRecipientSp extends SilentRecipient {
  @override
  final SilentAddress address;
  @override
  final Sats amountSat;
  @override
  final bool isMax;
  final int? label;

  const SilentRecipientSp({
    required this.address,
    required this.amountSat,
    required this.isMax,
    this.label,
  });
}

/// A standard on-chain (bc1...) recipient.
final class SilentRecipientStandard extends SilentRecipient {
  @override
  final SilentAddress address;
  @override
  final Sats amountSat;
  @override
  final bool isMax;

  const SilentRecipientStandard({
    required this.address,
    required this.amountSat,
    required this.isMax,
  });
}
