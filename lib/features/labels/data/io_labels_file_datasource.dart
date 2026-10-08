import 'dart:io';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/labels_file_port.dart';
import 'package:bull_logger/bull_logger.dart';

class IoLabelsFileDatasource implements LabelsFilePort {
  @override
  Future<Result<String, LabelFailure>> readText(
    String path, {
    required int maxBytes,
  }) async {
    final file = File(path);

    final int length;
    try {
      length = await file.length();
    } on FileSystemException catch (e, st) {
      log.warning('Failed to stat the labels file', error: e, trace: st);
      return const Err(LabelUnexpectedFailure('labels file stat failed'));
    }
    // Checked on disk, before reading. The codec enforces the same limit on
    //  the content.
    if (length > maxBytes) {
      return Err(LabelsFileTooLargeFailure(maxBytes: maxBytes));
    }

    try {
      return Ok(await file.readAsString());
    } on FileSystemException catch (e, st) {
      // Most often a binary file that is not valid UTF-8: the wrong file,
      //  not a bug.
      log.warning('Failed to read the labels file', error: e, trace: st);
      return const Err(LabelsFileUnreadableFailure());
    }
  }
}
