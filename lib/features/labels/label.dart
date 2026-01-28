import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';

class Label {
  final int id;
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  Label({
    required this.id,
    required this.type,
    required this.label,
    required this.reference,
    this.origin,
  });

  factory Label.tx({
    required int id,
    required String transactionId,
    required String label,
    String? origin,
  }) {
    return Label(
      id: id,
      type: LabelType.transaction,
      label: label,
      reference: transactionId,
      origin: origin,
    );
  }

  factory Label.addr({
    required int id,
    required String address,
    required String label,
    String? origin,
  }) {
    return Label(
      id: id,
      type: LabelType.address,
      label: label,
      reference: address,
      origin: origin,
    );
  }
}
