part of 'mempool_settings_cubit.dart';

@freezed
sealed class MempoolSettingsState with _$MempoolSettingsState {
  const factory MempoolSettingsState({
    @Default(false) bool isLiquid,
    MempoolServerRow? defaultServer,
    MempoolServerRow? customServer,
    @Default(false) bool isLoading,
    @Default(false) bool isSavingServer,
    @Default(false) bool isDeletingServer,
    MempoolFailure? failure,
  }) = _MempoolSettingsState;
  const MempoolSettingsState._();

  bool get hasCustomServer => customServer != null;

  bool get hasError => failure != null;

  bool get isProcessing => isLoading || isSavingServer || isDeletingServer;
}
