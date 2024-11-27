import 'package:freezed_annotation/freezed_annotation.dart';

part 'manual_state.freezed.dart';

@freezed
class ManualState with _$ManualState {
  const factory ManualState({
    @Default('') String error,
    @Default(false) bool recovered,
    @Default('') String backupKey,
    @Default('') String backupId,
    @Default('') String encrypted,
  }) = _ManualState;
}
