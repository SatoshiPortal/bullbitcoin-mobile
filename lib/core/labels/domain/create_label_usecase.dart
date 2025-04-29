import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/labelable.dart';

class CreateLabelUsecase {
  final LabelRepository _labelRepository;

  CreateLabelUsecase({required LabelRepository labelRepository})
      : _labelRepository = labelRepository;

  Future<void> execute<T extends Labelable>({
    required String origin,
    required T entity,
    required String label,
    bool? spendable,
  }) async {
    try {
      _labelRepository.store(
        label: label,
        origin: origin,
        entity: entity,
        spendable: spendable,
      );
    } catch (e) {
      throw CreateLabelException(e.toString());
    }
  }
}

class CreateLabelException implements Exception {
  final String message;

  CreateLabelException(this.message);
}
