part of 'sell_bloc.dart';

@freezed
sealed class SellState with _$SellState {
  const factory SellState.initial({
    GetExchangeUserSummaryException? getUserSummaryException,
  }) = SellInitialState;
  const factory SellState.amountInput({
    required UserSummary userSummary,
    required BitcoinUnit bitcoinUnit,
  }) = SellAmountInputState;
  const factory SellState.walletSelection({
    required UserSummary userSummary,
    required BitcoinUnit bitcoinUnit,
    required OrderAmount orderAmount,
    required FiatCurrency fiatCurrency,
    @Default(false) bool isCreatingSellOrder,
    SellError? error,
  }) = SellWalletSelectionState;
  const factory SellState.payment({
    required UserSummary userSummary,
    required BitcoinUnit bitcoinUnit,
    required OrderAmount orderAmount,
    required FiatCurrency fiatCurrency,
    Wallet? selectedWallet,
    required SellOrder sellOrder,
    @Default(false) bool isConfirmingPayment,
    @Default(false) bool isPolling,
    SellError? error,
    int? absoluteFees,
    @Default([]) List<WalletUtxo> utxos,
    @Default([]) List<WalletUtxo> selectedUtxos,
    @Default(true) bool replaceByFee,
    double? exchangeRateEstimate,
  }) = SellPaymentState;
  const factory SellState.success({
    required BitcoinUnit bitcoinUnit,
    required SellOrder sellOrder,
  }) = SellSuccessState;
  const SellState._();

  // Backward step: drop forward state. Same-type case resets transients.
  SellAmountInputState? get toCleanAmountInputState => switch (this) {
    final SellAmountInputState s => s,
    SellWalletSelectionState(:final userSummary, :final bitcoinUnit) =>
      SellAmountInputState(userSummary: userSummary, bitcoinUnit: bitcoinUnit),
    SellPaymentState(:final userSummary, :final bitcoinUnit) =>
      SellAmountInputState(userSummary: userSummary, bitcoinUnit: bitcoinUnit),
    _ => null,
  };

  SellWalletSelectionState? get toCleanWalletSelectionState => switch (this) {
    final SellWalletSelectionState s => s.copyWith(
      isCreatingSellOrder: false,
      error: null,
    ),
    SellPaymentState(
      :final userSummary,
      :final bitcoinUnit,
      :final orderAmount,
      :final fiatCurrency,
    ) =>
      SellWalletSelectionState(
        userSummary: userSummary,
        bitcoinUnit: bitcoinUnit,
        orderAmount: orderAmount,
        fiatCurrency: fiatCurrency,
      ),
    _ => null,
  };

  // Same-type reset: preserve all data fields, clear only transient UI flags.
  // Using copyWith here makes new fields safe-by-default — adding a field to
  // SellPaymentState can no longer silently drop it (was issue #2007).
  SellPaymentState? get toCleanPaymentState => switch (this) {
    final SellPaymentState s => s.copyWith(
      isConfirmingPayment: false,
      isPolling: false,
      error: null,
    ),
    _ => null,
  };

  FiatCurrency get fiatCurrency => switch (this) {
    SellInitialState() => FiatCurrency.cad,
    SellAmountInputState(:final userSummary) => FiatCurrency.fromCode(
      userSummary.currency ?? 'CAD',
    ),
    SellWalletSelectionState(:final fiatCurrency) => fiatCurrency,
    SellPaymentState(:final fiatCurrency) => fiatCurrency,
    SellSuccessState(:final sellOrder) => FiatCurrency.fromCode(
      sellOrder.payoutCurrency,
    ),
  };

  BitcoinUnit? get bitcoinUnit => switch (this) {
    SellInitialState() => null,
    SellAmountInputState(:final bitcoinUnit) => bitcoinUnit,
    SellWalletSelectionState(:final bitcoinUnit) => bitcoinUnit,
    SellPaymentState(:final bitcoinUnit) => bitcoinUnit,
    SellSuccessState(:final bitcoinUnit) => bitcoinUnit,
  };

  bool get isLimitedKycLevel => switch (this) {
    SellInitialState() => false,
    SellAmountInputState(:final userSummary) => userSummary.isLimitedKycLevel,
    SellWalletSelectionState(:final userSummary) =>
      userSummary.isLimitedKycLevel,
    SellPaymentState(:final userSummary) => userSummary.isLimitedKycLevel,
    SellSuccessState() => true, // Success state implies KYC was sufficient
  };

  bool get isLightKycLevel => switch (this) {
    SellInitialState() => false,
    SellAmountInputState(:final userSummary) => userSummary.isLightKycLevel,
    SellWalletSelectionState(:final userSummary) => userSummary.isLightKycLevel,
    SellPaymentState(:final userSummary) => userSummary.isLightKycLevel,
    SellSuccessState() => true, // Success state implies KYC was sufficient
  };

  bool get isFullyVerifiedKycLevel => switch (this) {
    SellInitialState() => false,
    SellAmountInputState(:final userSummary) =>
      userSummary.isFullyVerifiedKycLevel,
    SellWalletSelectionState(:final userSummary) =>
      userSummary.isFullyVerifiedKycLevel,
    SellPaymentState(:final userSummary) => userSummary.isFullyVerifiedKycLevel,
    SellSuccessState() => true, // Success state implies KYC was sufficient
  };

  UserSummary? get _userSummary => switch (this) {
    SellAmountInputState(:final userSummary) => userSummary,
    SellWalletSelectionState(:final userSummary) => userSummary,
    SellPaymentState(:final userSummary) => userSummary,
    _ => null,
  };

  /// Whether the user's KYC level permits transactions in [currency].
  /// Falls back to [fiatCurrency] when [currency] is null.
  bool isKycOk({FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? fiatCurrency;
    return _userSummary?.isKycOk(effectiveCurrency) ?? false;
  }

  /// Whether [amount] exceeds the per-transaction limit for the user's
  /// KYC level in [currency]. Falls back to [fiatCurrency] when null.
  bool isAmountExceeded(double amount, {FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? fiatCurrency;
    return _userSummary?.isAmountExceeded(amount, effectiveCurrency) ?? false;
  }

  /// Returns true when the "Complete KYC" prompt should be shown instead of
  /// the normal action button.
  bool needsKycUpgrade(double amount, {FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? fiatCurrency;
    return _userSummary?.needsKycUpgrade(amount, effectiveCurrency) ?? true;
  }
}

extension SellAmountInputStateX on SellAmountInputState {
  SellWalletSelectionState toWalletSelectionState({
    required OrderAmount orderAmount,
    required FiatCurrency fiatCurrency,
  }) {
    return SellWalletSelectionState(
      userSummary: userSummary,
      bitcoinUnit: bitcoinUnit,
      orderAmount: orderAmount,
      fiatCurrency: fiatCurrency,
    );
  }
}

extension SellWalletSelectionStateX on SellWalletSelectionState {
  SellPaymentState toSendPaymentState({
    required Wallet selectedWallet,
    required SellOrder createdSellOrder,
    int? absoluteFees,
    List<WalletUtxo>? utxos,
    double? exchangeRateEstimate,
  }) {
    return SellPaymentState(
      userSummary: userSummary,
      bitcoinUnit: bitcoinUnit,
      orderAmount: orderAmount,
      fiatCurrency: fiatCurrency,
      selectedWallet: selectedWallet,
      sellOrder: createdSellOrder,
      absoluteFees: absoluteFees,
      exchangeRateEstimate: exchangeRateEstimate,
      utxos: utxos ?? [],
    );
  }

  SellPaymentState toReceivePaymentState({
    required SellOrder createdSellOrder,
    double? exchangeRateEstimate,
  }) {
    return SellPaymentState(
      userSummary: userSummary,
      bitcoinUnit: bitcoinUnit,
      orderAmount: orderAmount,
      fiatCurrency: fiatCurrency,
      sellOrder: createdSellOrder,
      exchangeRateEstimate: exchangeRateEstimate,
    );
  }
}

extension SellPaymentStateX on SellPaymentState {
  SellSuccessState toSuccessState({required SellOrder sellOrder}) {
    return SellSuccessState(bitcoinUnit: bitcoinUnit, sellOrder: sellOrder);
  }

  String get bip21InvoiceData {
    final order = sellOrder;
    String invoiceString = '';

    switch (order.payinMethod) {
      case OrderPaymentMethod.bitcoin:
        if (order.bitcoinAddress != null) {
          final amountBtc = order.payinAmount;
          final address = order.bitcoinAddress!;

          final bip21Uri = Bip21Uri(
            scheme: 'bitcoin',
            address: address,
            amount: amountBtc,
          );
          invoiceString = bip21Uri.toString();
        }
      case OrderPaymentMethod.liquid:
        if (order.liquidAddress != null) {
          final amountBtc = order.payinAmount;
          final address = order.liquidAddress!;

          final bip21Uri = Bip21Uri(
            scheme: 'liquidnetwork',
            address: address,
            amount: amountBtc,
            options: {'assetid': AssetConstants.lbtcMainnet},
          );
          invoiceString = bip21Uri.toString();
        }
      case OrderPaymentMethod.lnInvoice:
        if (order.lightningInvoice != null) {
          invoiceString = order.lightningInvoice!;
        }
      default:
        break;
    }

    return invoiceString;
  }
}
