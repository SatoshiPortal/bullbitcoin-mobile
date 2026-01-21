import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';

class ExportLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;
  final LabelsConverterPort _labelConverter;

  ExportLabelsUsecase({
    required LabelsRepositoryPort labelRepository,
    required LabelsConverterPort labelConverter,
  }) : _labelRepository = labelRepository,
       _labelConverter = labelConverter;

  Future<String> call(LabelFormat format) async {
    final labels = await _labelRepository.fetchAll();
    final formattedLabels = _labelConverter.convertTo(
      format: format,
      labels: labels,
    );
    return (formattedLabels as FormattedLabelsBIP329).jsonl;
  }
}
