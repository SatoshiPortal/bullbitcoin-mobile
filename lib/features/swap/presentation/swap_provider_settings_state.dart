part of 'swap_provider_settings_cubit.dart';

@freezed
sealed class SwapProviderSettingsState with _$SwapProviderSettingsState {
  const factory SwapProviderSettingsState({
    @Default(<SwapProviderConfig>[]) List<SwapProviderConfig> providers,
    String? activeId,
    @Default(false) bool isLoading,
    @Default(false) bool isSwitching,
    @Default(false) bool isSaving,
    @Default(false) bool isDeleting,
    @Default(false) bool switchBlocked,
    SwapFailure? failure,
  }) = _SwapProviderSettingsState;
  const SwapProviderSettingsState._();

  bool get isProcessing => isLoading || isSwitching || isSaving || isDeleting;

  List<SwapProviderConfig> get customProviders =>
      providers.where((p) => !p.isBuiltIn).toList(growable: false);
}
