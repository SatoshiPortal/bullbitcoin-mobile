part of 'tor_settings_cubit.dart';

@freezed
sealed class TorSettingsState with _$TorSettingsState {
  const factory TorSettingsState({
    @Default(false) bool useTorProxy,
    @Default(9050) int torProxyPort,
    @Default(TorTransportMode.automatic) TorTransportMode transportMode,
    TorTransport? lastSuccessfulTransport,
    @Default(TorUninitialized()) TorConnectionState embeddedConnection,
    @Default(TorUninitialized()) TorConnectionState connection,
    TorConnectionState? externalProxyAttempt,
  }) = _TorSettingsState;
}
