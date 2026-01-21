import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';

class NewLabel {
  final LabelType type;
  final String reference;
  final String label;
  final String? origin;

  NewLabel({
    required this.type,
    required this.reference,
    required this.label,
    this.origin,
  });
}
