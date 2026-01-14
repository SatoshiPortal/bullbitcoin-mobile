import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';

class LabelsConverterAdapter implements LabelsConverterPort {
  final Bip329LabelsCodec _bip329labelsCodec;

  LabelsConverterAdapter(this._bip329labelsCodec);

  @override
  List<Label> convertFrom(FormattedLabels formattedLabels) {
    switch (formattedLabels) {
      case FormattedLabelsBIP329():
        return _bip329labelsCodec.decode(formattedLabels.jsonl);
    }
  }

  @override
  FormattedLabels convertTo({
    required LabelFormat format,
    required List<Label> labels,
  }) {
    switch (format) {
      case LabelFormat.bip329:
        final jsonl = _bip329labelsCodec.encode(labels);
        return FormattedLabelsBIP329(jsonl: jsonl);
    }
  }
}
