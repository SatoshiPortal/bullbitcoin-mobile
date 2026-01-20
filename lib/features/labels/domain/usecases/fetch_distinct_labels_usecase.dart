import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class FetchDistinctLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;

  FetchDistinctLabelsUsecase({required LabelsRepositoryPort labelRepository})
    : _labelRepository = labelRepository;

  Future<Set<String>> execute() async {
    try {
      final labels = await _labelRepository.fetchAll();
      final strings = labels.map((label) => label.label).toList();
      return strings.toSet();
    } on LabelError {
      rethrow;
    } catch (e) {
      log.severe('$FetchDistinctLabelsUsecase: $e');
      throw LabelError.unexpected('Failed to fetch distinct labels: $e');
    }
  }
}
