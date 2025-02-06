import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr/nostr.dart';

part 'settings_state.freezed.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    required Keychain keys,
    required String secret,
    required String relay,
    @Default('') String error,
  }) = _SettingsState;
}
