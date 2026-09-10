import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class Bip329LabelsState with _$Bip329LabelsState {
  const factory Bip329LabelsState.initial() = Bip329LabelsInitial;
  const factory Bip329LabelsState.loading() = Bip329LabelsLoading;
  const factory Bip329LabelsState.exportSuccess() = Bip329LabelsExportSuccess;
  const factory Bip329LabelsState.importSuccess({required int labelsCount}) =
      Bip329LabelsImportSuccess;
  const factory Bip329LabelsState.error({required LabelFailure failure}) =
      Bip329LabelsFailureState;
}
