import 'package:bb_mobile/core/labels/domain/export_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/import_labels_usecase.dart';
import 'package:bb_mobile/features/bip329_labels/state.dart';
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

  Future<void> exportLabels() async {
    try {
      emit(const Bip329LabelsState.loading());
      final labelsExported = await _exportLabelsUsecase.call();
      emit(Bip329LabelsState.exportSuccess(labelsCount: labelsExported));
    } catch (e) {
      emit(Bip329LabelsState.error(message: 'Export failed: $e'));
    }
  }

  Future<void> importLabels({String? walletId}) async {
    try {
      emit(const Bip329LabelsState.loading());

      final labelsImported = await _importLabelsUsecase.call();

      emit(Bip329LabelsState.importSuccess(labelsCount: labelsImported));
    } catch (e) {
      emit(Bip329LabelsState.error(message: 'Import failed: $e'));
    }
  }
}
