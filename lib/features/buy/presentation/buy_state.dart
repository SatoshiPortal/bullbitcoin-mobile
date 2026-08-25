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

  /// One slot per screen that renders a failure.
  ///
  /// The input, confirm and success screens share a single bloc, so within
  /// that shell [buyOrder] is what tells them apart: nothing reaches the
  /// confirm screen before an order exists, and the input screen is gone once
  /// one does.
  BuyFailure? get inputFailure => buyOrder == null ? failure : null;

  /// The success screen shares this slot but deliberately renders nothing: its
  /// only failure source is the 5s background payjoin poll, which the next tick
  /// clears, and an error under a completed order would alarm for nothing.
  BuyFailure? get confirmFailure => buyOrder == null ? null : failure;

  /// The accelerate routes each build their own bloc, so [buyOrder] says
  /// nothing about who a failure belongs to — it is still null while the entry
  /// refresh, the fee read and the rate read can each fail. Every failure that
  /// reaches an accelerate bloc belongs to the screen showing it.
  BuyFailure? get accelerateFailure => failure;

  bool get canOfferPayjoin =>
      payjoinGloballyEnabled &&
      userSummary?.payjoinReceiveEnabled == true &&
      selectedWallet?.isBitcoin == true &&
      selectedWallet?.isStandardLocalSingleSignatureWallet == true;

  bool get shouldUsePayjoin =>
      canOfferPayjoin && isPayjoinEnabled && amountSat != null;

  bool get canCreateOrder {
    return isPositiveAmount && hasDestination;
  }

  double _truncateToDecimals(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).truncate() / factor;
  }
}
