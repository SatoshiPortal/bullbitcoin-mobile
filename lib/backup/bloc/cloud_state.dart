import 'package:freezed_annotation/freezed_annotation.dart';

part 'cloud_state.freezed.dart';

@freezed
class CloudState with _$CloudState {
  const factory CloudState({
    @Default(false) bool loading,
    @Default('') String backupFolderId,
    @Default(null) DateTime? lastBackupAttempt,
    @Default('') String toast,
    @Default('') String error,
  }) = _CloudState;
}
