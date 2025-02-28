import 'package:freezed_annotation/freezed_annotation.dart';

part 'pdk_session_model.freezed.dart';

@freezed
class PdkSessionModel with _$PdkSessionModel {
  const factory PdkSessionModel({
    @Default('') String id,
  }) = _PdkSessionModel;
  const PdkSessionModel._();

  factory PdkSessionModel.fromJson(Map<String, dynamic> json) {
    return PdkSessionModel();
  }
}
