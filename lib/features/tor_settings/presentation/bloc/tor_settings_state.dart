part of 'tor_settings_cubit.dart';

@freezed
sealed class TorSettingsState with _$TorSettingsState {
  const factory TorSettingsState({
    @Default(TorStatus.unknown) TorStatus status,
    @Default(false) bool useTorProxy,
    @Default(9050) int torProxyPort,
  }) = _TorSettingsState;
}
