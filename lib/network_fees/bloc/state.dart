import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';
part 'state.g.dart';

@freezed
class NetworkFeesState with _$NetworkFeesState {
  const factory NetworkFeesState({
    @Default(0) int fees,
    @Default([]) List<int> feesList,
    @Default(2) int selectedFeesOption,
    @Default(0) int tempFees,
    @Default(2) int tempSelectedFeesOption,
    @Default(false) bool feesSaved,
    //
    @Default(false) bool loadingFees,
    @Default('') String errLoadingFees,
  }) = _NetworkFeesState;
  const NetworkFeesState._();

  factory NetworkFeesState.fromJson(Map<String, dynamic> json) => _$NetworkFeesStateFromJson(json);
}
