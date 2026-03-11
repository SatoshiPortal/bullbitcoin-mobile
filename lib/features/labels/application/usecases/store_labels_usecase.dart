import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/store_label_application.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';

class StoreLabelUsecase {
  final LabelsRepositoryPort _labelRepository;

  StoreLabelUsecase({required LabelsRepositoryPort labelRepository})
    : _labelRepository = labelRepository;

  Future<ApplicationLabel> execute(NewApplicationLabel label) async {
    try {
      final newLabel = NewLabel(
        type: label.type,
        label: label.label,
        reference: label.reference,
        origin: label.origin,
      );
      final storedLabel = await _labelRepository.store(newLabel);
      return LabelMapper.labelEntityToApplicationLabel(storedLabel);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected('Failed to batch labels: $e');
    }
  }
}
