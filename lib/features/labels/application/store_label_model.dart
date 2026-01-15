import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/primitive/label_type.dart';

/// DTO for storing labels.
///
/// This DTO is used as input to the [StoreLabelsUsecase] to avoid exposing
/// domain entities to outer layers. The use case is responsible for converting
/// this DTO into the domain [Label] entity.
class StoreLabelModel {
  final LabelType type;
  final String label;
  final String reference;
  final String? origin;

  const StoreLabelModel({
    required this.type,
    required this.label,
    required this.reference,
    this.origin,
  });

  /// Converts this DTO to a domain [Label] entity.
  ///
  /// This conversion should only be called within the application/domain layer.
  Label toDomain() {
    return Label(
      type: type,
      label: label,
      reference: reference,
      origin: origin,
    );
  }
}
