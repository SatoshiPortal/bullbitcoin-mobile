part of 'autoswap_settings_cubit.dart';

@freezed
abstract class AutoSwapSettingsState with _$AutoSwapSettingsState {
  const factory AutoSwapSettingsState({
    @Default(false) bool loading,
    @Default(false) bool saving,
    String? amountThresholdInput,
    String? feeThresholdInput,
    @Default(false) bool enabledToggle,
    String? error,
    AutoSwap? settings,
  }) = _AutoSwapSettingsState;

  const AutoSwapSettingsState._();
}
