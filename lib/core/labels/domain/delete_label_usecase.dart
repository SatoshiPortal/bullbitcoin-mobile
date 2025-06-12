import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/labelable.dart';

class DeleteLabelUsecase {
  final LabelRepository _labelRepository;

  DeleteLabelUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute<T extends Labelable>({
    required T entity,
    required String label,
  }) async {
    try {
      await _labelRepository.trashOneLabel(entity: entity, label: label);
    } catch (e) {
      throw DeleteLabelException(e.toString());
    }
  }
}

class DeleteLabelException implements Exception {
  final String message;

  DeleteLabelException(this.message);
}
