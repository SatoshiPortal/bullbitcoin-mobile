import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class DeleteLabelUsecase {
  final LabelsRepositoryPort _labelRepository;

  DeleteLabelUsecase({required LabelsRepositoryPort labelRepository})
    : _labelRepository = labelRepository;

  Future<void> execute(ApplicationLabel label) async {
    try {
      await _labelRepository.trashLabel(
        LabelMapper.applicationLabelToLabelEntity(label),
      );
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected('Failed to delete label $label: $e');
    }
  }
}
