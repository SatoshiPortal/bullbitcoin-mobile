import 'package:freezed_annotation/freezed_annotation.dart';

part 'social_setting_state.freezed.dart';

@freezed
class SocialSettingState with _$SocialSettingState {
  const factory SocialSettingState({
    @Default('') String secretKey,
    @Default('') String publicKey,
    @Default('') String receiverPublicKey,
    @Default('') String backupKey,
    @Default('ws://localhost:7000') String relay,
    @Default('') String error,
  }) = _SocialSettingState;
}
