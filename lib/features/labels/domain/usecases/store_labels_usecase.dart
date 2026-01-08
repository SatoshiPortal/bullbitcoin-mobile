import 'package:bb_mobile/features/labels/data/label_repository.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class StoreLabelsUsecase {
  final LabelsRepository _labelRepository;

  StoreLabelsUsecase({required LabelsRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute(List<Label> labels) async {
    try {
      await _labelRepository.store(labels);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected('Failed to batch labels: $e');
    }
  }
}
