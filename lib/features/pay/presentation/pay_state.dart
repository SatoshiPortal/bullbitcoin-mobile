part of 'pay_bloc.dart';

@freezed
sealed class PayState with _$PayState {
  const factory PayState.recipientSelection({
    UserSummary? userSummary,
    @Default(false) bool isLoadingUserSummary,
    PayError? error,
  }) = PayRecipientSelectionState;
  const factory PayState.amountInput({
    required RecipientViewModel selectedRecipient,
    required UserSummary userSummary,
    PayError? error,
  }) = PayAmountInputState;
  const factory PayState.walletSelection({
    required RecipientViewModel selectedRecipient,
    required UserSummary userSummary,
    required FiatAmount amount,
    @Default(false) bool isCreatingPayOrder,
    PayError? error,
  }) = PayWalletSelectionState;
  const factory PayState.payment({
    required RecipientViewModel selectedRecipient,
    required UserSummary userSummary,
    required FiatAmount amount,
    Wallet? selectedWallet,
    required FiatPaymentOrder payOrder,
    @Default(false) bool isConfirmingPayment,
    @Default(false) bool isPolling,
    PayError? error,
    int? absoluteFees,
    @Default([]) List<WalletUtxo> utxos,
    @Default([]) List<WalletUtxo> selectedUtxos,
    @Default(true) bool replaceByFee,
    double? exchangeRateEstimate,
  }) = PayPaymentState;
  const factory PayState.success({required FiatPaymentOrder payOrder}) =
      PaySuccessState;
  const PayState._();

  UserSummary? get userSummary => switch (this) {
    PayRecipientSelectionState(:final userSummary) => userSummary,
    PayAmountInputState(:final userSummary) => userSummary,
    PayWalletSelectionState(:final userSummary) => userSummary,
    PayPaymentState(:final userSummary) => userSummary,
    PaySuccessState() => null,
  };

  bool get isFullyVerifiedKycLevel =>
      userSummary?.isFullyVerifiedKycLevel == true;

  bool get isLimitedKycLevel => userSummary?.isLimitedKycLevel == true;

  bool get isLightKycLevel => userSummary?.isLightKycLevel == true;

  bool isKycOk({FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? this.currency;
    return userSummary?.isKycOk(effectiveCurrency) ?? false;
  }

  bool isAmountExceeded(double amount, {FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? this.currency;
    return userSummary?.isAmountExceeded(amount, effectiveCurrency) ?? false;
  }

  bool needsKycUpgrade(double amount, {FiatCurrency? currency}) {
    final effectiveCurrency = currency ?? this.currency;
    return userSummary?.needsKycUpgrade(amount, effectiveCurrency) ?? true;
  }

  FiatCurrency get currency => switch (this) {
    PayRecipientSelectionState(:final userSummary) => userSummary != null
        ? FiatCurrency.fromCode(userSummary.currency!)
        : FiatCurrency.cad,
    PayAmountInputState(:final selectedRecipient) => FiatCurrency.fromCode(
      selectedRecipient.currencyCode,
    ),
    PayWalletSelectionState(:final selectedRecipient) => FiatCurrency.fromCode(
      selectedRecipient.currencyCode,
    ),
    PayPaymentState(:final payOrder) => FiatCurrency.fromCode(
      payOrder.payoutCurrency,
    ),
    PaySuccessState(:final payOrder) => FiatCurrency.fromCode(
      payOrder.payoutCurrency,
    ),
  };

  // Backward step: drop forward state, reset transients on the destination.
  PayRecipientSelectionState? get cleanRecipientSelectionState => switch (this) {
    final PayRecipientSelectionState s => s.copyWith(
      isLoadingUserSummary: false,
      error: null,
    ),
    PayAmountInputState(:final userSummary) => PayRecipientSelectionState(
      userSummary: userSummary,
    ),
    PayWalletSelectionState(:final userSummary) => PayRecipientSelectionState(
      userSummary: userSummary,
    ),
    PayPaymentState(:final userSummary) => PayRecipientSelectionState(
      userSummary: userSummary,
    ),
    PaySuccessState() => null,
  };

  PayAmountInputState? get cleanAmountInputState => switch (this) {
    final PayAmountInputState s => s.copyWith(error: null),
    PayWalletSelectionState(:final selectedRecipient, :final userSummary) =>
      PayAmountInputState(
        selectedRecipient: selectedRecipient,
        userSummary: userSummary,
      ),
    PayPaymentState(:final selectedRecipient, :final userSummary) =>
      PayAmountInputState(
        selectedRecipient: selectedRecipient,
        userSummary: userSummary,
      ),
    _ => null,
  };

  PayWalletSelectionState? get cleanWalletSelectionState => switch (this) {
    final PayWalletSelectionState s => s.copyWith(
      isCreatingPayOrder: false,
      error: null,
    ),
    PayPaymentState(
      :final selectedRecipient,
      :final userSummary,
      :final amount,
    ) =>
      PayWalletSelectionState(
        selectedRecipient: selectedRecipient,
        userSummary: userSummary,
        amount: amount,
      ),
    _ => null,
  };

  // Same-type reset: preserve all data fields, clear only transient UI flags.
  // Using copyWith here makes new fields safe-by-default — adding a field to
  // PayPaymentState can no longer silently drop it (was issue #2007).
  PayPaymentState? get cleanPaymentState => switch (this) {
    final PayPaymentState s => s.copyWith(
      isConfirmingPayment: false,
      isPolling: false,
      error: null,
    ),
    _ => null,
  };
}

extension PayRecipientSelectionStateX on PayRecipientSelectionState {
  PayAmountInputState toAmountInputState({
    required RecipientViewModel selectedRecipient,
  }) {
    if (userSummary == null) {
      throw StateError('Cannot create amount input state without user summary');
    }

    return PayAmountInputState(
      selectedRecipient: selectedRecipient,
      userSummary: userSummary!,
    );
  }
}

extension PayAmountInputStateX on PayAmountInputState {
  PayWalletSelectionState toWalletSelectionState({required FiatAmount amount}) {
    return PayWalletSelectionState(
      userSummary: userSummary,
      amount: amount,
      selectedRecipient: selectedRecipient,
      isCreatingPayOrder: false,
    );
  }
}

extension PayWalletSelectionStateX on PayWalletSelectionState {
  PayPaymentState toSendPaymentState({
    required Wallet selectedWallet,
    required FiatPaymentOrder payOrder,
    List<WalletUtxo>? utxos,
    int? absoluteFees,
    double? exchangeRateEstimate,
  }) {
    return PayPaymentState(
      userSummary: userSummary,
      amount: amount,
      selectedRecipient: selectedRecipient,
      selectedWallet: selectedWallet,
      payOrder: payOrder,
      absoluteFees: absoluteFees,
      exchangeRateEstimate: exchangeRateEstimate,
      utxos: utxos ?? [],
    );
  }

  PayPaymentState toReceivePaymentState({
    required FiatPaymentOrder payOrder,
    double? exchangeRateEstimate,
  }) {
    return PayPaymentState(
      userSummary: userSummary,
      amount: amount,
      selectedRecipient: selectedRecipient,
      selectedWallet: null,
      payOrder: payOrder,
      exchangeRateEstimate: exchangeRateEstimate,
    );
  }
}

extension PayPaymentStateX on PayPaymentState {
  PaySuccessState toSuccessState({required FiatPaymentOrder payOrder}) {
    return PaySuccessState(payOrder: payOrder);
  }

  bool get isInternalWallet => selectedWallet != null;
  bool get isExternalWallet => selectedWallet == null;
  bool get canConfirmPayment => isInternalWallet && selectedUtxos.isNotEmpty;
  bool get isProcessing => isConfirmingPayment || isPolling;

  String get bip21InvoiceData {
    final order = payOrder;
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
