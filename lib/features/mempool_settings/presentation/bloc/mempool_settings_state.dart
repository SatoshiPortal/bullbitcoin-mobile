part of 'mempool_settings_cubit.dart';

@freezed
sealed class MempoolSettingsState with _$MempoolSettingsState {
  const factory MempoolSettingsState({
    @Default(false) bool isLiquid,
    MempoolServerDto? defaultServer,
    MempoolServerDto? customServer,
    MempoolSettingsDto? settings,
    @Default(false) bool isLoading,
    @Default(false) bool isSavingServer,
    @Default(false) bool isDeletingServer,
    @Default(false) bool isUpdatingSettings,
    SetCustomMempoolServerError? setServerError,
    MempoolValidationErrorType? validationErrorType,
    String? errorMessage,
  }) = _MempoolSettingsState;
  const MempoolSettingsState._();

  bool get hasCustomServer => customServer != null;

  bool get hasError => errorMessage != null || setServerError != null;

  bool get isProcessing =>
      isLoading || isSavingServer || isDeletingServer || isUpdatingSettings;
}
