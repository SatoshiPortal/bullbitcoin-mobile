part of 'pay_bloc.dart';

@freezed
sealed class PayState with _$PayState {
  const factory PayState.initial({
    ApiKeyException? apiKeyException,
    GetExchangeUserSummaryException? getUserSummaryException,
    ListRecipientsException? listRecipientsException,
  }) = PayInitialState;

  const factory PayState.recipientInput({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    Recipient? selectedRecipient,
    @Default(false) bool isCreatingPayOrder,
    @Default(false) bool isCreatingNewRecipient,
    @Default([]) List<CadBiller> cadBillers,
    @Default(false) bool isLoadingCadBillers,
    @Default(false) bool isLoadingRecipients,
    PayError? error,
  }) = PayRecipientInputState;
  const factory PayState.amountInput({
    required FiatAmount amount,
    required FiatCurrency currency,
    UserSummary? userSummary,
    Recipient? selectedRecipient,
  }) = PayAmountInputState;
  const factory PayState.walletSelection({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    required Recipient recipient,
    @Default(false) bool isCreatingPayOrder,
    PayError? error,
  }) = PayWalletSelectionState;
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

  FiatCurrency get currency {
    return when(
      initial: (_, _, _) => FiatCurrency.cad,
      amountInput:
          (_, currency, _, selectedRecipient) =>
              selectedRecipient != null
                  ? FiatCurrency.fromCode(
                    selectedRecipient.recipientType.currencyCode,
                  )
                  : currency,
      recipientInput:
          (_, _, _, currency, selectedRecipient, _, _, _, _, _, _) =>
              selectedRecipient != null
                  ? FiatCurrency.fromCode(
                    selectedRecipient.recipientType.currencyCode,
                  )
                  : currency,
      walletSelection: (_, _, _, currency, _, _, _) => currency,
      payment:
          (_, _, _, _, _, _, order, _, _, _, _, _, _, _, _) =>
              FiatCurrency.fromCode(order.payoutCurrency),
      success: (order) => FiatCurrency.fromCode(order.payoutCurrency),
    );
  }

  List<Recipient> get recipients {
    return when(
      initial: (_, recipientsException, _) => [],
      amountInput: (_, _, _, _) => [],
      recipientInput:
          (_, recipients, _, _, selectedRecipient, _, _, _, _, _, _) =>
              recipients,
      walletSelection: (_, recipients, _, _, _, _, _) => recipients,
      payment:
          (_, recipients, _, _, _, _, _, _, _, _, _, _, _, _, _) => recipients,
      success: (order) => [],
    );
  }

  List<Recipient> get eligibleRecipientsByCurrency {
    return recipients
        .where(
          (recipient) => recipient.recipientType.currencyCode == currency.code,
        )
        .toList();
  }

  PayAmountInputState? get cleanAmountInputState {
    return whenOrNull(
      amountInput:
          (amount, currency, userSummary, selectedRecipient) =>
              PayAmountInputState(
                amount: amount,
                currency: currency,
                userSummary: userSummary,
                selectedRecipient: selectedRecipient,
              ),
      recipientInput:
          (
            userSummary,
            _,
            amount,
            currency,
            selectedRecipient,
            _,
            _,
            _,
            _,
            _,
            _,
          ) => PayAmountInputState(
            amount: amount,
            currency: currency,
            userSummary: userSummary,
            selectedRecipient: selectedRecipient,
          ),
      walletSelection:
          (_, _, amount, currency, recipient, _, _) => PayAmountInputState(
            amount: amount,
            currency: currency,
            selectedRecipient: recipient,
          ),
      payment:
          (_, _, amount, currency, recipient, _, _, _, _, _, _, _, _, _, _) =>
              PayAmountInputState(
                amount: amount,
                currency: currency,
                selectedRecipient: recipient,
              ),
    );
  }

  PayRecipientInputState? get cleanRecipientInputState {
    return whenOrNull(
      recipientInput:
          (
            userSummary,
            recipients,
            amount,
            currency,
            selectedRecipient,
            _,
            _,
            _,
            _,
            _,
            _,
          ) => PayRecipientInputState(
            userSummary: userSummary,
            recipients: recipients,
            amount: amount,
            currency: currency,
            selectedRecipient: selectedRecipient,
          ),
      walletSelection:
          (userSummary, recipients, amount, currency, recipient, _, _) =>
              PayRecipientInputState(
                userSummary: userSummary,
                recipients: recipients,
                amount: amount,
                currency: currency,
                selectedRecipient: recipient,
              ),
      payment:
          (
            userSummary,
            recipients,
            amount,
            currency,
            recipient,
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
          ) => PayRecipientInputState(
            userSummary: userSummary,
            recipients: recipients,
            amount: amount,
            currency: currency,
            selectedRecipient: recipient,
          ),
    );
  }

  PayWalletSelectionState? get cleanWalletSelectionState {
    return whenOrNull(
      walletSelection:
          (userSummary, recipients, amount, currency, recipient, _, _) =>
              PayWalletSelectionState(
                userSummary: userSummary,
                recipients: recipients,
                amount: amount,
                currency: currency,
                recipient: recipient,
              ),
      payment:
          (
            userSummary,
            recipients,
            amount,
            currency,
            recipient,
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
            userSummary: userSummary,
            recipients: recipients,
            amount: amount,
            currency: currency,
            recipient: recipient,
          ),
    );
  }

  PayPaymentState? get cleanPaymentState {
    return whenOrNull(
      payment:
          (
            userSummary,
            recipients,
            amount,
            currency,
            recipient,
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
            userSummary: userSummary,
            recipients: recipients,
            amount: amount,
            currency: currency,
            recipient: recipient,
            selectedWallet: selectedWallet,
            payOrder: payOrder,
          ),
    );
  }
}

extension PayInitialStateX on PayInitialState {
  PayAmountInputState toAmountInputState({
    required FiatAmount amount,
    required FiatCurrency currency,
    UserSummary? userSummary,
  }) {
    return PayAmountInputState(
      amount: amount,
      currency: currency,
      userSummary: userSummary,
    );
  }
}

extension PayAmountInputStateX on PayAmountInputState {
  PayWalletSelectionState toWalletSelectionState({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required Recipient selectedRecipient,
  }) {
    return PayWalletSelectionState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      recipient: selectedRecipient,
      isCreatingPayOrder: false,
    );
  }
}

extension PayRecipientInputStateX on PayRecipientInputState {
  PayAmountInputState toAmountInputState({required Recipient recipient}) {
    return PayAmountInputState(
      amount: amount,
      currency: currency,
      userSummary: userSummary,
      selectedRecipient: recipient,
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
