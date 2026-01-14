import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class FetchLabelByReferenceUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchLabelByReferenceUsecase({required LabelsRepositoryPort labelRepository})
    : _labelRepository = labelRepository;

  Future<List<Label>> execute(String reference) async {
    try {
      return await _labelRepository.fetchByReference(reference);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected(
        'Failed to fetch label for reference $reference: $e',
      );
    }
  }
}
