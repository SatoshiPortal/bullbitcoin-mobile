import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';

abstract class LabelsConverterPort {
  FormattedLabels convertTo({
    required LabelFormat format,
    required List<Label> labels,
  });

  List<Label> convertFrom(FormattedLabels formattedLabels);
}
