import 'package:bb_mobile/features/labels/data/label_repository.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';

class FetchLabelByRefUsecase {
  final LabelsRepository _labelRepository;

  FetchLabelByRefUsecase({required LabelsRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<List<Label>> execute(String ref) async {
    try {
      return await _labelRepository.fetchByRef(ref);
    } on LabelError {
      rethrow;
    } catch (e) {
      throw LabelError.unexpected('Failed to fetch label by ref $ref: $e');
    }
  }
}
