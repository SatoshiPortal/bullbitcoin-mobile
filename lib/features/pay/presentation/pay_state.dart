part of 'pay_bloc.dart';

@freezed
sealed class PayState with _$PayState {
  const factory PayState.initial({
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
    ListRecipientsException? listRecipientsException,
  }) = PayInitialState;
  const factory PayState.amountInput({
    required UserSummary userSummary,
    required List<Recipient> recipients,
  }) = PayAmountInputState;
  const factory PayState.recipientInput({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    @Default(false) bool isCreatingPayOrder,
    @Default(false) bool isCreatingNewRecipient,
    @Default([]) List<CadBiller> cadBillers,
    @Default(false) bool isLoadingCadBillers,
    PayError? error,
    NewRecipient? newRecipient,
  }) = PayRecipientInputState;
  const factory PayState.walletSelection({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    required Recipient recipient,
    @Default(false) bool isCreatingPayOrder,
    PayError? error,
  }) = PayWalletSelectionState;
  const factory PayState.externalWalletNetworkSelection({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    required Recipient recipient,
    @Default(false) bool isCreatingPayOrder,
    PayError? error,
  }) = PayExternalWalletNetworkSelectionState;
  const factory PayState.payment({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    required Recipient recipient,
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
}

extension PayInitialStateX on PayInitialState {
  PayAmountInputState toAmountInputState({
    required UserSummary userSummary,
    required List<Recipient> recipients,
  }) {
    return PayAmountInputState(
      userSummary: userSummary,
      recipients: recipients,
    );
  }
}

extension PayAmountInputStateX on PayAmountInputState {
  PayRecipientInputState toRecipientInputState({
    required FiatAmount amount,
    required FiatCurrency currency,
  }) {
    return PayRecipientInputState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      isCreatingPayOrder: false,
      isCreatingNewRecipient: false,
      cadBillers: const [],
      isLoadingCadBillers: false,
    );
  }
}

extension PayRecipientInputStateX on PayRecipientInputState {
  PayAmountInputState toAmountInputState() {
    return PayAmountInputState(
      userSummary: userSummary,
      recipients: recipients,
    );
  }

  PayWalletSelectionState toWalletSelectionState({
    required Recipient recipient,
  }) {
    return PayWalletSelectionState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      recipient: recipient,
      isCreatingPayOrder: false,
    );
  }
}

extension PayWalletSelectionStateX on PayWalletSelectionState {
  PayRecipientInputState toRecipientInputState() {
    return PayRecipientInputState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      isCreatingPayOrder: false,
      isCreatingNewRecipient: false,
      cadBillers: const [],
      isLoadingCadBillers: false,
    );
  }

  PayExternalWalletNetworkSelectionState
  toExternalWalletNetworkSelectionState() {
    return PayExternalWalletNetworkSelectionState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      recipient: recipient,
      isCreatingPayOrder: false,
    );
  }

  PayPaymentState toSendPaymentState({
    required Wallet selectedWallet,
    required FiatPaymentOrder payOrder,
    int? absoluteFees,
    List<WalletUtxo>? utxos,
    double? exchangeRateEstimate,
  }) {
    return PayPaymentState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      recipient: recipient,
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
      recipients: recipients,
      amount: amount,
      currency: currency,
      recipient: recipient,
      selectedWallet: null,
      payOrder: payOrder,
      exchangeRateEstimate: exchangeRateEstimate,
    );
  }
}

extension PayExternalWalletNetworkSelectionStateX
    on PayExternalWalletNetworkSelectionState {
  PayWalletSelectionState toWalletSelectionState() {
    return PayWalletSelectionState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      recipient: recipient,
      isCreatingPayOrder: false,
    );
  }

  PayPaymentState toReceivePaymentState({
    required FiatPaymentOrder payOrder,
    double? exchangeRateEstimate,
  }) {
    return PayPaymentState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      recipient: recipient,
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

extension PayStateX on PayState {
  PayAmountInputState? get toCleanAmountInputState {
    return whenOrNull(
      amountInput: (userSummary, recipients) {
        return PayAmountInputState(
          userSummary: userSummary,
          recipients: recipients,
        );
      },
      recipientInput: (
        userSummary,
        recipients,
        amount,
        currency,
        isCreatingPayOrder,
        isCreatingNewRecipient,
        cadBillers,
        isLoadingCadBillers,
        error,
        newRecipient,
      ) {
        return PayAmountInputState(
          userSummary: userSummary,
          recipients: recipients,
        );
      },
      walletSelection: (
        userSummary,
        recipients,
        amount,
        currency,
        recipient,
        isCreatingPayOrder,
        error,
      ) {
        return PayAmountInputState(
          userSummary: userSummary,
          recipients: recipients,
        );
      },
      externalWalletNetworkSelection: (
        userSummary,
        recipients,
        amount,
        currency,
        recipient,
        isCreatingPayOrder,
        error,
      ) {
        return PayAmountInputState(
          userSummary: userSummary,
          recipients: recipients,
        );
      },
      payment: (
        userSummary,
        recipients,
        amount,
        currency,
        recipient,
        selectedWallet,
        payOrder,
        isConfirmingPayment,
        isPolling,
        error,
        absoluteFees,
        _,
        _,
        _,
        _,
      ) {
        return PayAmountInputState(
          userSummary: userSummary,
          recipients: recipients,
        );
      },
    );
  }

  PayWalletSelectionState? get toCleanWalletSelectionState {
    return whenOrNull(
      walletSelection: (
        userSummary,
        recipients,
        amount,
        currency,
        recipient,
        isCreatingPayOrder,
        error,
      ) {
        return PayWalletSelectionState(
          userSummary: userSummary,
          recipients: recipients,
          amount: amount,
          currency: currency,
          recipient: recipient,
        );
      },
      externalWalletNetworkSelection: (
        userSummary,
        recipients,
        amount,
        currency,
        recipient,
        isCreatingPayOrder,
        error,
      ) {
        return PayWalletSelectionState(
          userSummary: userSummary,
          recipients: recipients,
          amount: amount,
          currency: currency,
          recipient: recipient,
        );
      },
      payment: (
        userSummary,
        recipients,
        amount,
        currency,
        recipient,
        selectedWallet,
        payOrder,
        isConfirmingPayment,
        isPolling,
        error,
        absoluteFees,
        _,
        _,
        _,
        _,
      ) {
        return PayWalletSelectionState(
          userSummary: userSummary,
          recipients: recipients,
          amount: amount,
          currency: currency,
          recipient: recipient,
        );
      },
    );
  }

  PayPaymentState? get toCleanPaymentState {
    return whenOrNull(
      payment: (
        userSummary,
        recipients,
        amount,
        currency,
        recipient,
        selectedWallet,
        payOrder,
        isConfirmingPayment,
        isPolling,
        error,
        absoluteFees,
        _,
        _,
        _,
        _,
      ) {
        return PayPaymentState(
          userSummary: userSummary,
          recipients: recipients,
          amount: amount,
          currency: currency,
          recipient: recipient,
          selectedWallet: selectedWallet,
          payOrder: payOrder,
          absoluteFees: absoluteFees,
        );
      },
    );
  }
}
