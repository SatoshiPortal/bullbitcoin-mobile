import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/labels/domain/label_error.dart';

class DeleteLabelUsecase {
  final LabelRepository _labelRepository;

  DeleteLabelUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute(Label label) async {
    try {
      await _labelRepository.trashLabel(label);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected('Failed to delete label ${label.label}: $e');
    }
  }
}
