part of 'buy_bloc.dart';

@freezed
sealed class BuyState with _$BuyState {
  const factory BuyState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    GetExchangeUserSummaryException? getUserSummaryException,
    @Default({}) Map<String, double> balances,
    @Default('') String amountInput,
    @Default(true) bool isFiatCurrencyInput,
    @Default(BitcoinUnit.btc) BitcoinUnit bitcoinUnit,
    @Default('') String currencyInput,
    @Default(0.0) double exchangeRate,
    @Default([]) List<Wallet> wallets,
    GetWalletsException? getWalletsException,
    Wallet? selectedWallet,
    @Default('') String bitcoinAddressInput,
    GetReceiveAddressException? getNewReceiveAddressException,
    @Default(false) bool isCreatingOrder,
    BuyError? createOrderBuyError,
    @Default(false) bool isRefreshingOrder,
    RefreshBuyOrderException? refreshBuyOrderException,
    @Default(false) bool isConfirmingOrder,
    ConfirmBuyOrderException? confirmBuyOrderException,
    BuyOrder? buyOrder,
    @Default(true) bool isPayjoinEnabled,
    @Default(false) bool isUpdatingPayjoin,
    FeeOptions? accelerationNetworkFees,
    GetNetworkFeesException? getNetworkFeesException,
    ConvertSatsToCurrencyAmountException? convertSatsToCurrencyAmountException,
    @Default(false) bool isAcceleratingOrder,
    AccelerateBuyOrderException? accelerateBuyOrderException,
  }) = _BuyState;
  const BuyState._();

  bool get isFullyVerifiedKycLevel =>
      userSummary?.isFullyVerifiedKycLevel == true;

  bool get isLimitedKycLevel => userSummary?.isLimitedKycLevel == true;

  bool get isLightKycLevel => userSummary?.isLightKycLevel == true;

  bool isKycOk({FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? this.currency ?? FiatCurrency.cad;
    return userSummary?.isKycOk(effectiveCurrency) ?? false;
  }

  bool isAmountExceeded(double amount, {FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? this.currency ?? FiatCurrency.cad;
    return userSummary?.isAmountExceeded(amount, effectiveCurrency) ?? false;
  }

  bool needsKycUpgrade(double amount, {FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? this.currency ?? FiatCurrency.cad;
    return userSummary?.needsKycUpgrade(amount, effectiveCurrency) ?? true;
  }

  double? get balance => balances[currencyInput];

  int? get maxAmountSat => balance != null && exchangeRate > 0
      ? ConvertAmount.btcToSats(balance! / exchangeRate)
      : null;

  double? get amount => isFiatCurrencyInput
      ? _truncateToDecimals(
          double.tryParse(amountInput.replaceAll(',', '.').trim()) ?? 0,
          currency?.decimals ?? 2,
        )
      : amountBtc != null
      ? _truncateToDecimals(amountBtc! * exchangeRate, currency?.decimals ?? 2)
      : null;

  double? get amountBtc => isFiatCurrencyInput
      ? amount != null && exchangeRate > 0
            ? amount! / exchangeRate
            : null
      : bitcoinUnit == BitcoinUnit.btc
      ? double.tryParse(amountInput.replaceAll(',', '.').trim())
      : amountSat != null
      ? amountSat! * 1e-8
      : null;

  int? get amountSat => !isFiatCurrencyInput && bitcoinUnit == BitcoinUnit.sats
      ? int.tryParse(amountInput.trim())
      : amountBtc != null
      ? ConvertAmount.btcToSats(amountBtc!)
      : null;

  FiatCurrency? get currency =>
      currencyInput.isNotEmpty ? FiatCurrency.fromCode(currencyInput) : null;

  bool get isPositiveAmount {
    return amount != null && amount! > 0;
  }

  bool get showInsufficientBalanceError {
    return balance != null &&
        ((amount ?? 0) > balance! ||
            maxAmountSat != null &&
                amountSat != null &&
                amountSat! > maxAmountSat!);
  }

  bool get hasDestination {
    return selectedWallet != null || bitcoinAddressInput.isNotEmpty;
  }

  // Not gated on the trading setting: the switch stays visible (defaulted
  // from the setting, see _onStarted) so it can be flipped back on in-flow —
  // the per-order switch reads AND writes the global trading setting.
  bool get canOfferPayjoin =>
      userSummary?.payjoinReceiveEnabled == true &&
      selectedWallet?.network.isBitcoin == true;

  bool get shouldUsePayjoin =>
      canOfferPayjoin && isPayjoinEnabled && amountSat != null;

  bool get canCreateOrder {
    return isPositiveAmount && hasDestination && !isUpdatingPayjoin;
  }

  double _truncateToDecimals(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).truncate() / factor;
  }
}
