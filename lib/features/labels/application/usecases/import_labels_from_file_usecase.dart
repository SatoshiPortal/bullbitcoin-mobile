import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/domain/labels_file_port.dart';
import 'package:meta/meta.dart';

/// Reads a labels file the user picked, then imports it.
class ImportLabelsFromFileUsecase {
  final LabelsFilePort _labelsFile;
  final LabelsConverterPort _labelConverter;
  final ImportLabelsUsecase _importLabels;

  ImportLabelsFromFileUsecase({
    required this._labelsFile,
    required this._labelConverter,
    required this._importLabels,
  });

  /// Number of labels imported.
  @useResult
  Future<Result<int, LabelFailure>> execute({
    required LabelFormat format,
    required String path,
  }) async {
    final read = await _labelsFile.readText(
      path,
      maxBytes: _labelConverter.maxImportBytes(format),
    );
    switch (read) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return _importLabels.call(switch (format) {
          LabelFormat.bip329 => FormattedLabelsBIP329(jsonl: value),
        });
    }
  }
}
