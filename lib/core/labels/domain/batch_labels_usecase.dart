import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/labels/domain/label_error.dart';

class BatchLabelsUsecase {
  final LabelRepository _labelRepository;

  BatchLabelsUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute(List<Label> labels) async {
    try {
      await _labelRepository.batch(labels);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected('Failed to batch labels: $e');
    }
  }
}
