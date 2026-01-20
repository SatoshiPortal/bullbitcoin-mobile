import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';

class Label {
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  Label({
    required this.type,
    required this.label,
    required this.reference,
    required this.origin,
  });

  factory Label.tx({
    required String transactionId,
    required String label,
    String? origin,
  }) {
    return Label(
      type: LabelType.transaction,
      label: label,
      reference: transactionId,
      origin: origin,
    );
  }

  factory Label.addr({
    required String address,
    required String label,
    String? origin,
  }) {
    return Label(
      type: LabelType.address,
      label: label,
      reference: address,
      origin: origin,
    );
  }
}
