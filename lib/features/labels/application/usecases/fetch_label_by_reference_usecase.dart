import 'package:bb_mobile/features/labels/adapters/label_mapper.dart';
import 'package:bb_mobile/features/labels/application/application_label.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class FetchLabelByReferenceUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchLabelByReferenceUsecase({required LabelsRepositoryPort labelRepository})
    : _labelRepository = labelRepository;

  Future<List<ApplicationLabel>> execute(String reference) async {
    try {
      final labels = await _labelRepository.fetchByReference(reference);
      return labels
          .map((label) => LabelMapper.labelEntityToApplicationLabel(label))
          .toList();
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected(
        'Failed to fetch label for reference $reference: $e',
      );
    }
  }
}
