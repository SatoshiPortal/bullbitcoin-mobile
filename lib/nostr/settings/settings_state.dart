import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

part 'settings_state.freezed.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    required Keys keys,
    required String secret,
    required String relay,
    @Default('') String error,
  }) = _SettingsState;
}
