import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';

class NewApplicationLabel {
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  const NewApplicationLabel({
    required this.type,
    required this.label,
    required this.reference,
    this.origin,
  });
}
