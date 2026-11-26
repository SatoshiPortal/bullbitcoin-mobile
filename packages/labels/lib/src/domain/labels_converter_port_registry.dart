import 'package:labels/src/domain/label_format.dart';
import 'package:labels/src/domain/labels_converter_port.dart';

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
