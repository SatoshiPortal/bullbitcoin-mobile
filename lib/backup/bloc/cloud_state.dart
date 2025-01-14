import 'package:bb_mobile/_pkg/gdrive.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:recoverbull_dart/recoverbull_dart.dart';

part 'cloud_state.freezed.dart';

@freezed
class CloudState with _$CloudState {
  const factory CloudState({
    @Default(true) bool loading,
    GoogleDriveStorage? googleDriveStorage,
    @Default('') String toast,
    @Default('') String error,
  }) = _CloudState;
}
