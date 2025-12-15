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
      amountThresholdError: null,
    );
  }

  AutoSwapSettingsState updateTriggerBalance(
    String sanitizedValue,
    BitcoinUnit currentUnit,
  ) {
    String? triggerBalanceError;
    if (sanitizedValue.isNotEmpty &&
        amountThresholdInput != null &&
        amountThresholdInput!.isNotEmpty) {
      int balanceThresholdSats;
      if (currentUnit == BitcoinUnit.btc) {
        final btcAmount = double.tryParse(amountThresholdInput ?? '0') ?? 0;
        balanceThresholdSats = ConvertAmount.btcToSats(btcAmount);
      } else {
        balanceThresholdSats = int.tryParse(amountThresholdInput ?? '0') ?? 0;
      }

      int triggerBalanceSats;
      if (currentUnit == BitcoinUnit.btc) {
        final btcAmount = double.tryParse(sanitizedValue) ?? 0;
        triggerBalanceSats = ConvertAmount.btcToSats(btcAmount);
      } else {
        triggerBalanceSats = int.tryParse(sanitizedValue) ?? 0;
      }

      if (triggerBalanceSats > 0 &&
          balanceThresholdSats > 0 &&
          triggerBalanceSats < 2 * balanceThresholdSats) {
        triggerBalanceError = 'autoswapTriggerBalanceError';
      }
    }

    return copyWith(
      triggerBalanceSatsInput: sanitizedValue,
      error: triggerBalanceError,
    );
  }
}
