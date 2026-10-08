import 'dart:convert';

import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_from_file_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/presentation/state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Bip329LabelsCubit extends Cubit<Bip329LabelsState> {
  final ExportLabelsUsecase _exportLabelsUsecase;
  final ImportLabelsFromFileUsecase _importLabelsFromFileUsecase;
  final FilePicker _filePicker;

  Bip329LabelsCubit({
    required this._exportLabelsUsecase,
    required this._importLabelsFromFileUsecase,
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
    final String path;
    try {
      // FileType.any, not FileType.custom: on iOS, custom without extensions
      //  resolves to no document types and the picker refuses to open, and
      //  `.jsonl` has no system type to filter on either. A file that is not
      //  a labels file is rejected by the use-case with its own message.
      final result = await _filePicker.pickFiles(type: FileType.any);
      // The user dismissed the picker. Not a failure.
      if (result == null || result.files.isEmpty) return;
      final pickedPath = result.files.first.path;
      if (pickedPath == null) {
        emit(
          const Bip329LabelsState.error(
            failure: LabelUnexpectedFailure('picked file has no path'),
          ),
        );
        await _clearPickedFileCopies();
        return;
      }
      path = pickedPath;
    } on Object catch (e, st) {
      log.warning('Failed to open the labels file picker', error: e, trace: st);
      emit(
        Bip329LabelsState.error(
          failure: LabelUnexpectedFailure('file picker: ${e.runtimeType}'),
        ),
      );
      return;
    }

    emit(const Bip329LabelsState.loading());
    try {
      switch (await _importLabelsFromFileUsecase.execute(
        format: format,
        path: path,
      )) {
        case Ok(:final value):
          emit(Bip329LabelsState.importSuccess(labelsCount: value));
        case Err(:final failure):
          emit(Bip329LabelsState.error(failure: failure));
      }
    } finally {
      await _clearPickedFileCopies();
    }
  }

  /// On iOS and Android the picker hands back a copy of the document in the
  ///  app's temp directory. A labels file carries txids and addresses, so the
  ///  copy is removed once the import is done, whatever the outcome.
  Future<void> _clearPickedFileCopies() async {
    try {
      await _filePicker.clearTemporaryFiles();
    } on UnimplementedError {
      // Desktop pickers return the real path, so there is no copy to clear.
    } on Object catch (e, st) {
      // Housekeeping only: never let it mask the import result.
      log.warning('Failed to clear picked file copies', error: e, trace: st);
    }
  }
}
