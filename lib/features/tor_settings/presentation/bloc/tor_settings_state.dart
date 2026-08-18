part of 'tor_settings_cubit.dart';

@freezed
sealed class TorSettingsState with _$TorSettingsState {
  const factory TorSettingsState({
    @Default(false) bool useTorProxy,
    @Default(9050) int torProxyPort,
    @Default(TorUninitialized()) TorConnectionState connection,
  }) = _TorSettingsState;
}
