part of 'pay_bloc.dart';

@freezed
sealed class PayState with _$PayState {
  const factory PayState.recipientInput({
    UserSummary? userSummary,
    List<Recipient>? recipients,
    Recipient? selectedRecipient,
    @Default(false) bool isCreatingPayOrder,
    @Default(false) bool isCreatingNewRecipient,
    @Default([]) List<CadBiller> cadBillers,
    @Default(false) bool isLoadingCadBillers,
    @Default(false) bool isLoadingRecipients,
    PayError? error,
  }) = PayRecipientInputState;
  const factory PayState.amountInput({
    required FiatCurrency currency,
    required FiatAmount amount,
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required Recipient selectedRecipient,
  }) = PayAmountInputState;
  const factory PayState.walletSelection({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    required Recipient selectedRecipient,
    @Default(false) bool isCreatingPayOrder,
    PayError? error,
  }) = PayWalletSelectionState;
  const factory PayState.payment({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required FiatAmount amount,
    required FiatCurrency currency,
    required Recipient selectedRecipient,
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
      amountInput:
          (currency, _, _, _, selectedRecipient) => FiatCurrency.fromCode(
            selectedRecipient.recipientType.currencyCode,
          ),
      recipientInput:
          (_, _, selectedRecipient, _, _, _, _, _, _) =>
              selectedRecipient != null
                  ? FiatCurrency.fromCode(
                    selectedRecipient.recipientType.currencyCode,
                  )
                  : FiatCurrency.cad,
      walletSelection: (_, _, _, currency, _, _, _) => currency,
      payment:
          (_, _, _, currency, _, _, payOrder, _, _, _, _, _, _, _, _) =>
              FiatCurrency.fromCode(payOrder.payoutCurrency),
      success: (order) => FiatCurrency.fromCode(order.payoutCurrency),
    );
  }

  List<Recipient> get recipients {
    return when(
      amountInput: (_, _, _, recipients, _) => recipients,
      recipientInput: (_, recipients, _, _, _, _, _, _, _) => recipients ?? [],
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
      recipientInput:
          (
            userSummary,
            recipients,
            selectedRecipient,
            _,
            _,
            _,
            _,
            _,
            _,
          ) => PayAmountInputState(
            currency:
                selectedRecipient != null
                    ? FiatCurrency.fromCode(
                      selectedRecipient.recipientType.currencyCode,
                    )
                    : FiatCurrency.cad,
            amount: const FiatAmount(0.0),
            userSummary: userSummary!,
            recipients: recipients ?? [],
            selectedRecipient:
                selectedRecipient ??
                (throw StateError(
                  'Cannot create amount input state without selected recipient',
                )),
          ),
      amountInput:
          (currency, amount, userSummary, recipients, selectedRecipient) =>
              PayAmountInputState(
                currency: currency,
                amount: amount,
                userSummary: userSummary,
                recipients: recipients,
                selectedRecipient: selectedRecipient,
              ),
      walletSelection:
          (_, _, _, _, _, _, _) =>
              null, // Cannot create amount input from wallet selection
      payment:
          (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
              null, // Cannot create amount input from payment
    );
  }

  PayRecipientInputState? get cleanRecipientInputState {
    return whenOrNull(
      recipientInput:
          (userSummary, recipients, selectedRecipient, _, _, _, _, _, _) =>
              PayRecipientInputState(
                userSummary: userSummary,
                recipients: recipients,
                selectedRecipient: selectedRecipient,
              ),
      walletSelection:
          (_, _, _, _, _, _, _) =>
              null, // Cannot create recipient input from wallet selection
      payment:
          (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
              null, // Cannot create recipient input from payment
    );
  }

  PayWalletSelectionState? get cleanWalletSelectionState {
    return whenOrNull(
      walletSelection:
          (
            userSummary,
            recipients,
            amount,
            currency,
            selectedRecipient,
            _,
            _,
          ) => PayWalletSelectionState(
            userSummary: userSummary,
            recipients: recipients,
            amount: amount,
            currency: currency,
            selectedRecipient: selectedRecipient,
          ),
      payment:
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
            _,
            _,
            _,
            _,
          ) => PayWalletSelectionState(
            userSummary: userSummary,
            recipients: recipients,
            amount: amount,
            currency: currency,
            selectedRecipient: selectedRecipient,
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
            selectedRecipient,
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
            selectedRecipient: selectedRecipient,
            selectedWallet: selectedWallet,
            payOrder: payOrder,
          ),
    );
  }
}

extension PayAmountInputStateX on PayAmountInputState {
  PayWalletSelectionState toWalletSelectionState({
    required Recipient selectedRecipient,
  }) {
    return PayWalletSelectionState(
      userSummary: userSummary,
      recipients: recipients,
      amount: amount,
      currency: currency,
      selectedRecipient: selectedRecipient,
      isCreatingPayOrder: false,
    );
  }
}

extension PayRecipientInputStateX on PayRecipientInputState {
  PayAmountInputState toAmountInputState({required Recipient recipient}) {
    if (userSummary == null) {
      throw StateError('Cannot create amount input state without user summary');
    }
    return PayAmountInputState(
      currency: FiatCurrency.fromCode(recipient.recipientType.currencyCode),
      amount: const FiatAmount(0.0),
      userSummary: userSummary!,
      recipients: recipients ?? [],
      selectedRecipient: recipient,
    );
  }

  PayWalletSelectionState toWalletSelectionState({
    required Recipient recipient,
  }) {
    if (userSummary == null) {
      throw StateError(
        'Cannot create wallet selection state without user summary',
      );
    }
    return PayWalletSelectionState(
      userSummary: userSummary!,
      recipients: recipients ?? [],
      amount: const FiatAmount(0.0),
      currency: FiatCurrency.fromCode(recipient.recipientType.currencyCode),
      selectedRecipient: recipient,
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
      recipients: recipients,
      amount: amount,
      currency: currency,
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
