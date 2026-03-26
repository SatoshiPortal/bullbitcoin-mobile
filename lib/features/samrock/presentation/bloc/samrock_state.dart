import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'samrock_state.freezed.dart';

@freezed
abstract class SamrockState with _$SamrockState {
  const factory SamrockState.initial() = SamrockInitial;

  const factory SamrockState.parsed({
    required SamrockSetupRequest request,
  }) = SamrockParsed;

  const factory SamrockState.loading({
    required SamrockSetupRequest request,
  }) = SamrockLoading;

  const factory SamrockState.success({
    required SamrockSetupRequest request,
    required SamrockSetupResponse response,
  }) = SamrockSuccess;

  const factory SamrockState.error({
    required String message,
    SamrockSetupRequest? request,
  }) = SamrockError;
}
