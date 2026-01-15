import 'package:bb_mobile/features/labels/application/store_label_model.dart';
import 'package:bb_mobile/features/labels/primitive/label_type.dart';

class StoreLabelEnvelope {
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  StoreLabelEnvelope({
    required this.type,
    required this.label,
    required this.reference,
    required this.origin,
  });

  /// Creates a transaction label DTO.
  factory StoreLabelEnvelope.tx({
    required String transactionId,
    required String label,
    String? origin,
  }) {
    return StoreLabelEnvelope(
      type: LabelType.transaction,
      label: label,
      reference: transactionId,
      origin: origin,
    );
  }

  /// Creates an address label DTO.
  factory StoreLabelEnvelope.addr({
    required String address,
    required String label,
    String? origin,
  }) {
    return StoreLabelEnvelope(
      type: LabelType.address,
      label: label,
      reference: address,
      origin: origin,
    );
  }

  StoreLabelModel toModel() {
    return StoreLabelModel(
      type: type,
      label: label,
      reference: reference,
      origin: origin,
    );
  }
}
