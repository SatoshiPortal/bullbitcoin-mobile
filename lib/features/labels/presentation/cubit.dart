import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:bb_mobile/features/labels/presentation/state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Bip329LabelsCubit extends Cubit<Bip329LabelsState> {
  final ExportLabelsUsecase _exportLabelsUsecase;
  final ImportLabelsUsecase _importLabelsUsecase;
  final FilePicker _filePicker;

  Bip329LabelsCubit({
    required this._exportLabelsUsecase,
    required this._importLabelsUsecase,
    FilePicker? filePicker,
  }) : _filePicker = filePicker ?? FilePicker.platform,
       super(const Bip329LabelsState.initial());

  Future<void> exportLabels(LabelFormat format) async {
    emit(const Bip329LabelsState.loading());

    final String jsonl;
    switch (await _exportLabelsUsecase.call(format)) {
      case Ok(:final value):
        jsonl = value;
      case Err(:final failure):
        emit(Bip329LabelsState.error(failure: failure));
        return;
    }

    // Switched on the format rather than hardcoding .jsonl: adding a
    //  LabelFormat should not compile until someone has decided what its
    //  file is called.
    final extension = switch (format) {
      LabelFormat.bip329 => 'jsonl',
    };
    final filename =
        'bull_labels_${DateTime.now().toIso8601WithoutMilliseconds()}'
        '.$extension';
    final String? savedTo;
    try {
      // The file picker is a platform channel and the only thing left here
      //  that throws; the use-case above owns its own boundary now.
      savedTo = await _filePicker.saveFile(
        bytes: utf8.encode(jsonl),
        fileName: filename,
      );
    } on Object catch (e, st) {
      log.warning('Failed to save the labels file', error: e, trace: st);
      emit(const Bip329LabelsState.error(failure: LabelsExportFailure()));
      return;
    }

    if (savedTo == null) {
      // The user dismissed the save dialog. saveFile returns null for that,
      //  and it used to be thrown as 'File not saved' — so backing out of
      //  the picker told the user something had gone wrong. Nothing did.
      emit(const Bip329LabelsState.initial());
      return;
    }

    emit(const Bip329LabelsState.exportSuccess());
  }

  /// Lets the user pick a labels file, then imports it.
  Future<void> importLabelsFromFile(LabelFormat format) async {
    final PlatformFile picked;
    try {
      // FileType.any, not FileType.custom: on iOS, custom without extensions
      //  resolves to no document types and the picker refuses to open, and
      //  `.jsonl` has no system type to filter on either. A file that is not
      //  a labels file is rejected by the use-case with its own message.
      final result = await _filePicker.pickFiles();
      // The user dismissed the picker. Not a failure.
      if (result == null || result.files.isEmpty) return;
      picked = result.files.first;
    } on Object catch (e, st) {
      log.warning('Failed to open the labels file picker', error: e, trace: st);
      emit(
        Bip329LabelsState.error(
          failure: LabelUnexpectedFailure('file picker: ${e.runtimeType}'),
        ),
      );
      return;
    }

    // Checked on the reported size, before reading, so a huge file is never
    //  loaded into memory. The codec enforces the same limit on the content.
    final maxBytes = switch (format) {
      LabelFormat.bip329 => Bip329LabelsCodec.maxImportBytes,
    };
    if (picked.size > maxBytes) {
      emit(
        Bip329LabelsState.error(
          failure: LabelsFileTooLargeFailure(maxBytes: maxBytes),
        ),
      );
      return;
    }

    final path = picked.path;
    if (path == null) {
      emit(
        const Bip329LabelsState.error(
          failure: LabelUnexpectedFailure('picked file has no path'),
        ),
      );
      return;
    }

    final String data;
    try {
      data = await File(path).readAsString();
    } on Object catch (e, st) {
      // Most often a binary file that is not valid UTF-8: the wrong file,
      //  not a bug.
      log.warning('Failed to read the labels file', error: e, trace: st);
      emit(
        const Bip329LabelsState.error(failure: LabelsFileUnreadableFailure()),
      );
      return;
    }

    await importLabels(format: format, data: data);
  }

  Future<void> importLabels({
    required LabelFormat format,
    required String data,
  }) async {
    emit(const Bip329LabelsState.loading());

    switch (format) {
      case LabelFormat.bip329:
        switch (await _importLabelsUsecase.call(
          FormattedLabelsBIP329(jsonl: data),
        )) {
          case Ok(:final value):
            emit(Bip329LabelsState.importSuccess(labelsCount: value));
          case Err(:final failure):
            // Forwarded as-is: the use-case already told "wrong file" apart
            //  from "too big" and "empty", which is the whole point.
            emit(Bip329LabelsState.error(failure: failure));
        }
    }
  }
}
