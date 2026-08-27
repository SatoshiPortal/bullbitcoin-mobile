import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/domain/decoded_labels.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:bb_mobile/features/labels/bip329_label_record.dart';

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
  List<Bip329LabelRecord> convertToMetadataRecords(List<LabelEntity> labels) {
    return _bip329labelsCodec.encodeMetadataRecords(labels);
  }

  @override
  List<NewLabel> convertFromMetadataRecords(List<Bip329LabelRecord> records) {
    return _bip329labelsCodec.decodeMetadataRecords(records);
  }
}
