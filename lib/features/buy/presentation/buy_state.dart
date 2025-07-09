part of 'buy_bloc.dart';

@freezed
sealed class BuyState with _$BuyState {
  const factory BuyState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
    @Default('') String amountInput,
    @Default('') String currencyInput,
    double? exchangeRate,
    @Default([]) List<Wallet> wallets,
    GetWalletsException? getWalletsException,
    Wallet? selectedWallet,
    @Default('') String bitcoinAddressInput,
    GetNewReceiveAddressException? getNewReceiveAddressException,
    @Default(false) bool isCreatingOrder,
    CreateBuyOrderException? createBuyOrderException,
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

  Map<String, double> get balances =>
      userSummary?.balances.fold<Map<String, double>>({}, (map, balance) {
        map[balance.currencyCode] = balance.amount;
        return map;
      }) ??
      {};

  double? get balance => balances[currencyInput];

  double? get amount => double.tryParse(amountInput);

  FiatCurrency get currency => FiatCurrency.fromCode(currencyInput);

  bool get isAmountTooLow {
    return amount == null || amount! <= 0;
  }

  bool get isBalanceTooLow {
    return balance == null || (amount ?? 0) > balance!;
  }

  bool get isValidDestination {
    return selectedWallet != null || bitcoinAddressInput.isNotEmpty;
  }

  bool get canCreateOrder {
    return !isAmountTooLow && !isBalanceTooLow && isValidDestination;
  }
}
