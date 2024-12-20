import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';
part 'settings_state.g.dart';

@freezed
class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(false) bool notifications,
    @Default(false) bool privacyView,
    @Default(20) int reloadWalletTimer,
    String? language,
    List<String>? languageList,
    @Default(false) bool loadingLanguage,
    @Default('') String errLoadingLanguage,
    @Default(true) bool defaultRBF,
    @Default(true) bool defaultPayjoin,
    @Default(1) int homeLayout,
    @Default(false) bool removeSwapWarnings,
  }) = _SettingsState;
  const SettingsState._();

  factory SettingsState.fromJson(Map<String, dynamic> json) => _$SettingsStateFromJson(json);
}
