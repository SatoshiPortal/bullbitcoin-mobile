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
    AutoswapFailure? failure,
    AutoswapFailure? amountThresholdFailure,
    AutoswapFailure? triggerBalanceFailure,
    AutoswapFailure? feeThresholdFailure,
    AutoSwap? settings,
    BitcoinUnit? bitcoinUnit,
    @Default(false) bool alwaysBlock,
    @Default(false) bool showInfo,
    @Default([]) List<Wallet> availableBitcoinWallets,
    String? selectedBitcoinWalletId,
    @Default(false) bool loadingWallets,
    String? boltzServerUrlInput,
    AutoswapFailure? boltzServerUrlFailure,
  }) = _AutoSwapSettingsState;

  const AutoSwapSettingsState._();

  BitcoinUnit get unit => bitcoinUnit ?? BitcoinUnit.sats;

  AutoSwapSettingsState toggleBitcoinUnit() {
    if (bitcoinUnit == null) return this;

    final newUnit = bitcoinUnit == BitcoinUnit.btc
        ? BitcoinUnit.sats
        : BitcoinUnit.btc;

    String? newAmountThresholdInput;
    if (amountThresholdInput != null && amountThresholdInput!.isNotEmpty) {
      if (bitcoinUnit == BitcoinUnit.btc) {
        final btcAmount = double.tryParse(amountThresholdInput!) ?? 0;
        final satsAmount = ConvertAmount.btcToSats(btcAmount);
        newAmountThresholdInput = satsAmount.toString();
      } else {
        final satsAmount = int.tryParse(amountThresholdInput!) ?? 0;
        final btcAmount = ConvertAmount.satsToBtc(satsAmount);
        newAmountThresholdInput = btcAmount.toString();
      }
    }

    String? newTriggerBalanceSatsInput;
    if (triggerBalanceSatsInput != null &&
        triggerBalanceSatsInput!.isNotEmpty) {
      if (bitcoinUnit == BitcoinUnit.btc) {
        final btcAmount = double.tryParse(triggerBalanceSatsInput!) ?? 0;
        final satsAmount = ConvertAmount.btcToSats(btcAmount);
        newTriggerBalanceSatsInput = satsAmount.toString();
      } else {
        final satsAmount = int.tryParse(triggerBalanceSatsInput!) ?? 0;
        final btcAmount = ConvertAmount.satsToBtc(satsAmount);
        newTriggerBalanceSatsInput = btcAmount.toString();
      }
    }

    return copyWith(
      bitcoinUnit: newUnit,
      amountThresholdInput: newAmountThresholdInput,
      triggerBalanceSatsInput: newTriggerBalanceSatsInput,
      amountThresholdFailure: null,
    );
  }
}
