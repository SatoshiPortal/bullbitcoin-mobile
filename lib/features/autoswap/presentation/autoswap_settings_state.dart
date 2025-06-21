part of 'autoswap_settings_cubit.dart';

@freezed
abstract class AutoSwapSettingsState with _$AutoSwapSettingsState {
  const factory AutoSwapSettingsState({
    @Default(false) bool loading,
    @Default(false) bool saving,
    @Default(false) bool successfullySaved,
    String? amountThresholdInput,
    String? feeThresholdInput,
    @Default(false) bool enabledToggle,
    String? error,
    AutoSwap? settings,
    BitcoinUnit? bitcoinUnit,
  }) = _AutoSwapSettingsState;

  const AutoSwapSettingsState._();
}
