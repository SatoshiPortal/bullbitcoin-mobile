import 'package:bb_mobile/_pkg/gdrive.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:googleapis/drive/v3.dart';

part 'cloud_state.freezed.dart';

@freezed
class CloudState with _$CloudState {
  const factory CloudState({
    @Default(false) bool loading,
    GoogleDriveApi? googleDriveApi,
    @Default([]) List<File> availableBackups,
    @Default(('', '')) (String, String) selectedBackup,
    @Default('') String toast,
    @Default('') String error,
  }) = _CloudState;
}
