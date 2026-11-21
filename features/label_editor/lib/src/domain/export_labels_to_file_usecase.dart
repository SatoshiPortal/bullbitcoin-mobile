import 'dart:convert';

import 'package:bull_logger/bull_logger.dart';
import 'package:file_system/file_system.dart';
import 'package:labels/labels.dart';
import 'package:meta/meta.dart';
import 'package:primitives/generic_extensions.dart';
import 'package:primitives/primitives.dart';

class ExportLabelsToFileUsecase {
  final LabelsFacade _labels;
  final FileSystem _fileSystem;

  ExportLabelsToFileUsecase({required this._labels, required this._fileSystem});

  @useResult
  Future<Result<bool, LabelFailure>> execute(LabelFormat format) async {
    final String content;
    switch (await _labels.exportLabels(format)) {
      case Ok(:final value):
        content = value;
      case Err(:final failure):
        return Err(failure);
    }
    final extension = switch (format) {
      LabelFormat.bip329 => 'jsonl',
    };
    final filename =
        'bull_labels_${DateTime.now().toIso8601WithoutMilliseconds()}'
        '.$extension';
    final saved = await _fileSystem.save(
      bytes: utf8.encode(content),
      filename: filename,
    );
    return saved.mapErr((failure) {
      log.warning('Failed to save the labels file', error: failure.logMessage);
      return const LabelsExportFailure();
    });
  }
}
