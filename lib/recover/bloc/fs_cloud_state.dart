import 'package:freezed_annotation/freezed_annotation.dart';

part 'fs_cloud_state.freezed.dart';

@freezed
class FsCloudState with _$FsCloudState {
  const factory FsCloudState({
    @Default('') String error,
    @Default(false) bool recovered,
    @Default('') String backupKey,
    @Default('') String backupId,
    @Default('') String encrypted,
  }) = _FsCloudState;
}
