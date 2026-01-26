import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class Bip329LabelsState with _$Bip329LabelsState {
  const factory Bip329LabelsState.initial() = _Initial;
  const factory Bip329LabelsState.loading() = _Loading;
  const factory Bip329LabelsState.exportSuccess() = _ExportSuccess;
  const factory Bip329LabelsState.importSuccess({required int labelsCount}) =
      _ImportSuccess;
  const factory Bip329LabelsState.error({required String message}) = _Error;
}
