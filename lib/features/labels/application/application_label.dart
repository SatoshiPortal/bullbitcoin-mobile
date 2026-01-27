import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';

class ApplicationLabel {
  final int id;
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  const ApplicationLabel({
    required this.id,
    required this.type,
    required this.label,
    required this.reference,
    this.origin,
  });
}
