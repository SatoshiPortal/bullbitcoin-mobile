import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/label_error.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class FetchDistinctLabelsUsecase {
  final LabelRepository _labelRepository;

  FetchDistinctLabelsUsecase({required LabelRepository labelRepository})
    : _labelRepository = labelRepository;

  Future<List<String>> execute() async {
    try {
      return await _labelRepository.fetchDistinct();
    } on LabelError {
      rethrow;
    } catch (e) {
      log.severe('$FetchDistinctLabelsUsecase: $e');
      throw LabelError.unexpected('Failed to fetch distinct labels: $e');
    }
  }
}
