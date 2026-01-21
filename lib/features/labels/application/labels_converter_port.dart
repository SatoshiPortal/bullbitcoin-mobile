import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/domain/new_label_entity.dart';

abstract class LabelsConverterPort {
  FormattedLabels convertTo({
    required LabelFormat format,
    required List<LabelEntity> labels,
  });

  List<NewLabelEntity> convertFrom(FormattedLabels formattedLabels);
}
