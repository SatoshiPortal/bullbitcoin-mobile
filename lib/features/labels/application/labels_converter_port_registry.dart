import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';

class LabelsConverterPortRegistry {
  final Map<LabelFormat, LabelsConverterPort> _converters;

  LabelsConverterPortRegistry(this._converters);

  LabelsConverterPort getConverter(LabelFormat format) {
    final converter = _converters[format];
    if (converter == null) {
      throw ArgumentError('No converter registered for format: $format');
    }
    return converter;
  }
}
