import 'package:bb_mobile/_pkg/gdrive.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cloud_state.freezed.dart';

@freezed
class CloudState with _$CloudState {
  const factory CloudState({
    @Default(true) bool loading,
    Gdrive? gdrive,
    @Default('') String toast,
  }) = _CloudState;
}
