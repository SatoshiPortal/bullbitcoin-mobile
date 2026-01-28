import 'dart:convert';

import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/presentation/state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Bip329LabelsCubit extends Cubit<Bip329LabelsState> {
  final ExportLabelsUsecase _exportLabelsUsecase;
  final ImportLabelsUsecase _importLabelsUsecase;

  Bip329LabelsCubit({
    required ExportLabelsUsecase exportLabelsUsecase,
    required ImportLabelsUsecase importLabelsUsecase,
  }) : _exportLabelsUsecase = exportLabelsUsecase,
       _importLabelsUsecase = importLabelsUsecase,
       super(const Bip329LabelsState.initial());

  Future<void> exportLabels(LabelFormat format) async {
    try {
      emit(const Bip329LabelsState.loading());
      switch (format) {
        case LabelFormat.bip329:
          final jsonl = await _exportLabelsUsecase.call(format);
          final filename =
              'bull_labels_${DateTime.now().toIso8601WithoutMilliseconds()}.jsonl';
          final result = await FilePicker.platform.saveFile(
            bytes: utf8.encode(jsonl),
            fileName: filename,
          );
          if (result == null) throw 'File not saved';
          break;
      }
      emit(Bip329LabelsState.exportSuccess());
    } catch (e) {
      emit(Bip329LabelsState.error(message: 'Export failed: $e'));
    }
  }

  Future<void> importLabels({
    required LabelFormat format,
    required String data,
  }) async {
    try {
      emit(const Bip329LabelsState.loading());

      int importedLabels = 0;
      switch (format) {
        case LabelFormat.bip329:
          importedLabels = await _importLabelsUsecase.call(
            FormattedLabelsBIP329(jsonl: data),
          );
          break;
      }
      emit(Bip329LabelsState.importSuccess(labelsCount: importedLabels));
    } catch (e) {
      emit(Bip329LabelsState.error(message: 'Import failed: $e'));
    }
  }
}
