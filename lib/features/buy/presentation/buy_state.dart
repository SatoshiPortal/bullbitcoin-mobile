part of 'buy_bloc.dart';

@freezed
sealed class BuyState with _$BuyState {
  const factory BuyState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    ApiKeyException? apiKeyException,
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
    GetNewReceiveAddressException? getNewReceiveAddressException,
    @Default(false) bool isCreatingOrder,
    BuyError? createOrderBuyError,
    @Default(false) bool isRefreshingOrder,
    RefreshBuyOrderException? refreshBuyOrderException,
    @Default(false) bool isConfirmingOrder,
    ConfirmBuyOrderException? confirmBuyOrderException,
    BuyOrder? buyOrder,
    FeeOptions? accelerationNetworkFees,
    GetNetworkFeesException? getNetworkFeesException,
    ConvertSatsToCurrencyAmountException? convertSatsToCurrencyAmountException,
    @Default(false) bool isAcceleratingOrder,
    AccelerateBuyOrderException? accelerateBuyOrderException,
  }) = _BuyState;
  const BuyState._();

  bool get isFullyVerifiedKycLevel =>
      userSummary?.isFullyVerifiedKycLevel == true;

  double? get balance => balances[currencyInput];

  int? get maxAmountSat =>
      balance != null && exchangeRate > 0
          ? ConvertAmount.btcToSats(balance! / exchangeRate)
          : null;

  double? get amount =>
      isFiatCurrencyInput
          ? _truncateToDecimals(
            double.tryParse(amountInput.replaceAll(',', '.').trim()) ?? 0,
            currency?.decimals ?? 2,
          )
          : amountBtc != null
          ? _truncateToDecimals(
            amountBtc! * exchangeRate,
            currency?.decimals ?? 2,
          )
          : null;

  double? get amountBtc =>
      isFiatCurrencyInput
          ? amount != null && exchangeRate > 0
              ? amount! / exchangeRate
              : null
          : bitcoinUnit == BitcoinUnit.btc
          ? double.tryParse(amountInput.replaceAll(',', '.').trim())
          : amountSat != null
          ? amountSat! * 1e-8
          : null;

  int? get amountSat =>
      !isFiatCurrencyInput && bitcoinUnit == BitcoinUnit.sats
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

  bool get canCreateOrder {
    return isPositiveAmount && hasDestination;
  }

  double _truncateToDecimals(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).truncate() / factor;
  }
}
