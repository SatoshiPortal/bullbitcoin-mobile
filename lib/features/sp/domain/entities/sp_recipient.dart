import 'package:bb_mobile/features/sp/domain/entities/sp_address.dart';
import 'package:primitives/primitives.dart';

/// A send output. Domain mirror of the bwk `RecipientView` FFI union; the wire
/// type stays in `data/` behind `SpRecipientMapper`.
sealed class SpRecipient {
  const SpRecipient();

  SpAddress get address;
  Sats get amountSat;
  bool get isMax;
}

/// A silent payment (sp1/tsp1) recipient. [label] is the bwk output label.
final class SpRecipientSp extends SpRecipient {
  @override
  final SpAddress address;
  @override
  final Sats amountSat;
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
  final SpAddress address;
  @override
  final Sats amountSat;
  @override
  final bool isMax;

  const SpRecipientStandard({
    required this.address,
    required this.amountSat,
    required this.isMax,
  });
}
