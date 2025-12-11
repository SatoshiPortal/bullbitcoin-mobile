part of 'autoswap_settings_cubit.dart';

@freezed
abstract class AutoSwapSettingsState with _$AutoSwapSettingsState {
  const factory AutoSwapSettingsState({
    @Default(false) bool loading,
    @Default(false) bool saving,
    @Default(false) bool successfullySaved,
    String? amountThresholdInput,
    String? triggerBalanceSatsInput,
    String? feeThresholdInput,
    @Default(false) bool enabledToggle,
    String? error,
    MinimumAmountThresholdException? amountThresholdError,
    MaximumFeeThresholdException? feeThresholdError,
    AutoSwap? settings,
    BitcoinUnit? bitcoinUnit,
    @Default(false) bool alwaysBlock,
    @Default(false) bool showInfo,
    @Default([]) List<Wallet> availableBitcoinWallets,
    String? selectedBitcoinWalletId,
    @Default(false) bool loadingWallets,
  }) = _AutoSwapSettingsState;

  const AutoSwapSettingsState._();
}
