import 'package:bb_mobile/features/labels/data/label_repository.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class FetchAllLabelsUsecase {
  final LabelsRepository _labelRepository;

  FetchAllLabelsUsecase({required LabelsRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<List<Label>> execute() async {
    try {
      return await _labelRepository.fetchAll();
    } on LabelError {
      rethrow;
    } catch (e) {
      log.severe('$FetchAllLabelsUsecase: $e');
      throw LabelError.unexpected('Failed to fetch distinct labels: $e');
    }
  }
}
