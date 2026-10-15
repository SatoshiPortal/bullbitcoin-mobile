part of 'buy_bloc.dart';

@freezed
sealed class BuyState with _$BuyState {
  const factory BuyState({
    @Default(false) bool isStarted,
    UserSummary? userSummary,
    @Default({}) Map<String, double> balances,
    @Default('') String amountInput,
    @Default(true) bool isFiatCurrencyInput,
    @Default(BitcoinUnit.btc) BitcoinUnit bitcoinUnit,
    @Default('') String currencyInput,
    @Default(0.0) double exchangeRate,
    @Default([]) List<Wallet> wallets,
    Wallet? selectedWallet,
    @Default('') String bitcoinAddressInput,
    @Default(false) bool isCreatingOrder,
    @Default(false) bool isRefreshingOrder,
    @Default(false) bool isConfirmingOrder,
    BuyOrder? buyOrder,
    @Default(false) bool payjoinGloballyEnabled,
    @Default(true) bool isPayjoinEnabled,
    FeeOptions? accelerationNetworkFees,
    @Default(false) bool isAcceleratingOrder,
    BuyFailure? failure,
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

  int? get maxAmountSat {
    final available = balance;
    return available != null && exchangeRate > 0
        ? ConvertAmount.btcToSats(available / exchangeRate)
        : null;
  }

  double? get amount {
    if (isFiatCurrencyInput) {
      return _truncateToDecimals(
        double.tryParse(amountInput.replaceAll(',', '.').trim()) ?? 0,
        currency?.decimals ?? 2,
      );
    }
    final btc = amountBtc;
    return btc == null
        ? null
        : _truncateToDecimals(btc * exchangeRate, currency?.decimals ?? 2);
  }

  double? get amountBtc {
    if (isFiatCurrencyInput) {
      final fiat = amount;
      return fiat != null && exchangeRate > 0 ? fiat / exchangeRate : null;
    }
    if (bitcoinUnit == BitcoinUnit.btc) {
      return double.tryParse(amountInput.replaceAll(',', '.').trim());
    }
    final sats = amountSat;
    return sats == null ? null : sats * 1e-8;
  }

  int? get amountSat {
    if (!isFiatCurrencyInput && bitcoinUnit == BitcoinUnit.sats) {
      return int.tryParse(amountInput.trim());
    }
    final btc = amountBtc;
    return btc == null ? null : ConvertAmount.btcToSats(btc);
  }

  FiatCurrency? get currency =>
      currencyInput.isNotEmpty ? FiatCurrency.fromCode(currencyInput) : null;

  bool get isPositiveAmount {
    return amount != null && amount! > 0;
  }

  bool get showInsufficientBalanceError {
    final available = balance;
    if (available == null) return false;
    final maximum = maxAmountSat;
    final sats = amountSat;
    return (amount ?? 0) > available ||
        maximum != null && sats != null && sats > maximum;
  }

  bool get hasDestination {
    return selectedWallet != null || bitcoinAddressInput.isNotEmpty;
  }

  /// Input failures occur before order creation starts. Leaving confirmation
  /// clears a creation failure before the input screen becomes active again.
  BuyFailure? get inputFailure => buyOrder == null ? failure : null;

  /// Creation can fail before an order exists: confirmation renders that
  /// failure as well as errors while refreshing or confirming a loaded order.
  BuyFailure? get confirmFailure => failure;

  /// The accelerate routes each build their own bloc, so [buyOrder] says
  /// nothing about who a failure belongs to — it is still null while the entry
  /// refresh, the fee read and the rate read can each fail. Every failure that
  /// reaches an accelerate bloc belongs to the screen showing it.
  BuyFailure? get accelerateFailure => failure;

  bool get canOfferPayjoin =>
      payjoinGloballyEnabled &&
      userSummary?.payjoinReceiveEnabled == true &&
      selectedWallet?.network.isBitcoin == true;

  bool get shouldUsePayjoin =>
      canOfferPayjoin && isPayjoinEnabled && isPayjoinAmountAllowed;

  bool get isPayjoinAmountAllowed =>
      PayjoinPolicy.allowsExchangeAmount(amountSat);

  bool get canCreateOrder {
    return isPositiveAmount && hasDestination;
  }

  double _truncateToDecimals(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).truncate() / factor;
  }
}
