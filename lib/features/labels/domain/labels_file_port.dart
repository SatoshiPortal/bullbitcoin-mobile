import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:meta/meta.dart';

/// Reads a labels file the user picked, so the import flow never touches
/// `dart:io` above the data layer.
abstract interface class LabelsFilePort {
  /// Reads the file at [path] as UTF-8 text.
  ///
  /// Rejects a file larger than [maxBytes] before reading it, so a huge file
  /// is never loaded into memory.
  @useResult
  Future<Result<String, LabelFailure>> readText(
    String path, {
    required int maxBytes,
  });
}
