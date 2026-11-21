import 'package:labels/src/data/bip329_codec.dart';
import 'package:labels/src/domain/decoded_labels.dart';
import 'package:labels/src/domain/formatted_labels.dart';
import 'package:labels/src/domain/label_entity.dart';
import 'package:labels/src/domain/label_format.dart';
import 'package:labels/src/domain/labels_converter_port.dart';

class LabelsConverterAdapter implements LabelsConverterPort {
  final Bip329LabelsCodec _bip329labelsCodec;

  LabelsConverterAdapter(this._bip329labelsCodec);

  @override
  DecodedLabels convertFrom(FormattedLabels formattedLabels) {
    switch (formattedLabels) {
      case FormattedLabelsBIP329():
        return _bip329labelsCodec.decode(formattedLabels.jsonl);
    }
  }

  @override
  FormattedLabels convertTo({
    required LabelFormat format,
    required List<LabelEntity> labels,
    List<({String walletId, String txId, int vout})> frozen = const [],
  }) {
    switch (format) {
      case LabelFormat.bip329:
        final jsonl = _bip329labelsCodec.encode(labels, frozen: frozen);
        return FormattedLabelsBIP329(jsonl: jsonl);
    }
  }

  @override
  int maxImportBytes(LabelFormat format) => switch (format) {
    LabelFormat.bip329 => Bip329LabelsCodec.maxImportBytes,
  };
}
