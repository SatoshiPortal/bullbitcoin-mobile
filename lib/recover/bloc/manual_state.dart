import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:recoverbull_dart/recoverbull_dart.dart';

part 'manual_state.freezed.dart';

@freezed
class ManualState with _$ManualState {
  const factory ManualState({
    @Default('') String error,
    @Default(false) bool loading,
    GoogleDriveStorage? googleDriveStorage,
    @Default([]) List<File> availableBackups,
    @Default(false) bool recovered,
    @Default('') String backupKey,
    @Default('') String backupId,
    @Default('') String encrypted,
  }) = _ManualState;
}
