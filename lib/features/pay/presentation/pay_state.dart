part of 'pay_bloc.dart';

@freezed
sealed class PayState with _$PayState {
  const factory PayState.amountInput({
    required RecipientViewModel selectedRecipient,
    UserSummary? userSummary,
    @Default(false) bool isLoadingUserSummary,
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

  UserSummary? get userSummary {
    return whenOrNull(
      amountInput: (_, userSummary, _, _) => userSummary,
      walletSelection: (_, userSummary, _, _, _) => userSummary,
      payment: (_, userSummary, _, _, _, _, _, _, _, _, _, _, _) => userSummary,
      success: (_) => null,
    );
  }

  FiatCurrency get currency {
    return when(
      amountInput:
          (selectedRecipient, _, _, _) =>
              FiatCurrency.fromCode(selectedRecipient.currencyCode),
      walletSelection:
          (selectedRecipient, _, _, _, _) =>
              FiatCurrency.fromCode(selectedRecipient.currencyCode),
      payment:
          (_, _, _, _, payOrder, _, _, _, _, _, _, _, _) =>
              FiatCurrency.fromCode(payOrder.payoutCurrency),
      success: (order) => FiatCurrency.fromCode(order.payoutCurrency),
    );
  }

  PayAmountInputState? get cleanAmountInputState {
    return whenOrNull(
      amountInput:
          (selectedRecipient, userSummary, _, _) => PayAmountInputState(
            selectedRecipient: selectedRecipient,
            userSummary: userSummary,
          ),
      walletSelection:
          (selectedRecipient, userSummary, _, _, _) => PayAmountInputState(
            selectedRecipient: selectedRecipient,
            userSummary: userSummary,
          ),
      payment:
          (selectedRecipient, userSummary, _, _, _, _, _, _, _, _, _, _, _) =>
              PayAmountInputState(
                selectedRecipient: selectedRecipient,
                userSummary: userSummary,
              ),
    );
  }

  PayWalletSelectionState? get cleanWalletSelectionState {
    return whenOrNull(
      walletSelection:
          (selectedRecipient, userSummary, amount, _, _) =>
              PayWalletSelectionState(
                selectedRecipient: selectedRecipient,
                userSummary: userSummary,
                amount: amount,
              ),
      payment:
          (
            selectedRecipient,
            userSummary,
            amount,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
          ) => PayWalletSelectionState(
            selectedRecipient: selectedRecipient,
            userSummary: userSummary,
            amount: amount,
          ),
    );
  }

  PayPaymentState? get cleanPaymentState {
    return whenOrNull(
      payment:
          (
            selectedRecipient,
            userSummary,
            amount,
            selectedWallet,
            payOrder,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
          ) => PayPaymentState(
            selectedRecipient: selectedRecipient,
            userSummary: userSummary,
            amount: amount,
            selectedWallet: selectedWallet,
            payOrder: payOrder,
          ),
    );
  }
}

extension PayAmountInputStateX on PayAmountInputState {
  PayWalletSelectionState toWalletSelectionState({required FiatAmount amount}) {
    if (userSummary == null) {
      throw StateError('Cannot create amount input state without user summary');
    }

    return PayWalletSelectionState(
      userSummary: userSummary!,
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
