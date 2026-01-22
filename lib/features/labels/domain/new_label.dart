import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';

class NewLabel {
  final int? id; // Used for updating existing labels
  final LabelType type;
  final String reference;
  final String label;
  final String? origin;

  NewLabel({
    this.id,
    required this.type,
    required this.reference,
    required this.label,
    this.origin,
  });
}
