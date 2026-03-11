import 'package:bb_mobile/features/labels/application/labels_converter_port_registry.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';

class ExportLabelsUsecase {
  final LabelsRepositoryPort _labelRepository;
  final LabelsConverterPortRegistry _converterRegistry;

  ExportLabelsUsecase({
    required LabelsRepositoryPort labelRepository,
    required LabelsConverterPortRegistry converterRegistry,
  }) : _labelRepository = labelRepository,
       _converterRegistry = converterRegistry;

  Future<String> call(LabelFormat format) async {
    final labels = await _labelRepository.fetchAll();
    final converter = _converterRegistry.getConverter(format);
    final formattedLabels = converter.convertTo(
      format: format,
      labels: labels,
    );
    return _getExportString(formattedLabels);
  }

  String _getExportString(FormattedLabels formattedLabels) {
    switch (formattedLabels) {
      case FormattedLabelsBIP329():
        return formattedLabels.jsonl;
    }
  }
}
