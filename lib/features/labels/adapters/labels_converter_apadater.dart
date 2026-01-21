import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/domain/new_label_entity.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';

class LabelsConverterAdapter implements LabelsConverterPort {
  final Bip329LabelsCodec _bip329labelsCodec;

  LabelsConverterAdapter(this._bip329labelsCodec);

  @override
  List<NewLabelEntity> convertFrom(FormattedLabels formattedLabels) {
    switch (formattedLabels) {
      case FormattedLabelsBIP329():
        final newBip329Labels = _bip329labelsCodec.decode(
          formattedLabels.jsonl,
        );
        return newBip329Labels
            .map(
              (newBip329Label) => NewLabelEntity(
                type: newBip329Label.type,
                reference: newBip329Label.reference,
                label: newBip329Label.label,
                origin: newBip329Label.origin,
              ),
            )
            .toList();
    }
  }

  @override
  FormattedLabels convertTo({
    required LabelFormat format,
    required List<LabelEntity> labels,
  }) {
    switch (format) {
      case LabelFormat.bip329:
        final jsonl = _bip329labelsCodec.encode(labels);
        return FormattedLabelsBIP329(jsonl: jsonl);
    }
  }
}
