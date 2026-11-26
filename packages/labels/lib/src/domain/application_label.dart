import 'package:labels/src/domain/label_entity.dart';
import 'package:labels/src/domain/primitive/label_type.dart';

class ApplicationLabel {
  final int id;
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  factory ApplicationLabel.fromEntity(LabelEntity label) => ApplicationLabel(
    id: label.id,
    type: label.type,
    label: label.label,
    reference: label.reference,
    origin: label.origin,
  );

  const ApplicationLabel({
    required this.id,
    required this.type,
    required this.label,
    required this.reference,
    this.origin,
  });
}
