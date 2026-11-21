import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_from_file_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Bip329LabelsCubit extends Cubit<Bip329LabelsState> {
  final ExportLabelsUsecase _exportLabelsUsecase;
  final ImportLabelsFromFileUsecase _importLabelsFromFileUsecase;

  Bip329LabelsCubit({
    required this._exportLabelsUsecase,
    required this._importLabelsFromFileUsecase,
  }) : super(const Bip329LabelsState.initial());

  Future<void> exportLabels(LabelFormat format) async {
    emit(const Bip329LabelsState.loading());

    final result = await _exportLabelsUsecase.save(format);
    if (isClosed) return;
    switch (result) {
      case Ok(value: true):
        emit(const Bip329LabelsState.exportSuccess());
      case Ok(value: false):
        emit(const Bip329LabelsState.initial());
      case Err(:final failure):
        emit(Bip329LabelsState.error(failure: failure));
    }
  }

  Future<void> importLabelsFromFile(LabelFormat format) async {
    final result = await _importLabelsFromFileUsecase.execute(
      format: format,
      onPicked: () {
        if (!isClosed) emit(const Bip329LabelsState.loading());
      },
    );
    if (isClosed) return;
    switch (result) {
      case Ok(value: final value?):
        emit(Bip329LabelsState.importSuccess(labelsCount: value));
      case Ok(value: null):
        break;
      case Err(:final failure):
        emit(Bip329LabelsState.error(failure: failure));
    }
  }
}
