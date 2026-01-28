import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';

class NewLabel {
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  NewLabel({
    required this.type,
    required this.label,
    required this.reference,
    this.origin,
  });

  factory NewLabel.tx({
    required String transactionId,
    required String label,
    String? origin,
  }) {
    return NewLabel(
      type: LabelType.transaction,
      label: label,
      reference: transactionId,
      origin: origin,
    );
  }

  factory NewLabel.addr({
    required String address,
    required String label,
    String? origin,
  }) {
    return NewLabel(
      type: LabelType.address,
      label: label,
      reference: address,
      origin: origin,
    );
  }
}
