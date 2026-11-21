import 'dart:convert';

import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:file_system/file_system.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Reads a labels file the user picked, then imports it.
class ImportLabelsFromFileUsecase {
  final FileSystem _fileSystem;
  final LabelsConverterPort _labelConverter;
  final ImportLabelsUsecase _importLabels;

  ImportLabelsFromFileUsecase({
    required this._fileSystem,
    required this._labelConverter,
    required this._importLabels,
  });

  /// Returns the import count, or null when the document picker was dismissed.
  @useResult
  Future<Result<int?, LabelFailure>> execute({
    required LabelFormat format,
    required void Function() onPicked,
  }) async {
    final PickedDocument? document;
    switch (await _fileSystem.pick()) {
      case Ok(:final value):
        document = value;
      case Err(:final failure):
        log.warning(
          'Failed to open the labels file picker',
          error: failure.logMessage,
        );
        return Err(
          LabelUnexpectedFailure('file picker: ${failure.logMessage}'),
        );
    }
    if (document == null) return const Ok(null);

    try {
      if (document.path == null) {
        return const Err(LabelUnexpectedFailure('picked file has no path'));
      }
      onPicked();
      final maxBytes = _labelConverter.maxImportBytes(format);
      switch (await _fileSystem.read(document, maxBytes: maxBytes)) {
        case Err(:final failure):
          if (failure.kind == FileSystemFailureKind.tooLarge) {
            return Err(LabelsFileTooLargeFailure(maxBytes: maxBytes));
          }
          if (failure.kind == FileSystemFailureKind.missing) {
            return const Err(LabelUnexpectedFailure('labels file is missing'));
          }
          log.warning(
            'Failed to read the labels file',
            error: failure.logMessage,
          );
          return const Err(LabelsFileUnreadableFailure());
        case Ok(:final value):
          final String content;
          try {
            content = utf8.decode(value);
          } on FormatException {
            return const Err(LabelsFileUnreadableFailure());
          }
          return await _importLabels.call(switch (format) {
            LabelFormat.bip329 => FormattedLabelsBIP329(jsonl: content),
          });
      }
    } finally {
      if (await _fileSystem.clearTemporaryFiles() case Err(:final failure)) {
        log.warning(
          'Failed to clear picked file copies',
          error: failure.logMessage,
        );
      }
    }
  }
}
