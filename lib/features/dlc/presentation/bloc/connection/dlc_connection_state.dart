part of 'dlc_connection_cubit.dart';

@freezed
abstract class DlcConnectionState with _$DlcConnectionState {
  const factory DlcConnectionState({
    @Default(false) bool isChecking,
    DlcConnectionStatus? connectionStatus,
    Exception? error,
  }) = _DlcConnectionState;
  const DlcConnectionState._();

  bool get isHealthy => connectionStatus?.isHealthy ?? false;
}
