import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';

class ImportLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;
  final LabelsConverterPort _labelConverter;

  ImportLabelsUsecase({
    required LabelsRepositoryPort labelRepository,
    required LabelsConverterPort labelConverter,
  }) : _labelRepository = labelRepository,
       _labelConverter = labelConverter;

  Future<int> call(FormattedLabels labels) async {
    try {
      final entities = _labelConverter.convertFrom(labels);
      await _labelRepository.store(entities);
      return entities.length;
    } catch (e) {
      log.severe('Failed to import labels: $e');
      throw ImportLabelsError('Failed to import labels: $e');
    }
  }
}

class ImportLabelsError extends BullException {
  ImportLabelsError(super.message);
}
