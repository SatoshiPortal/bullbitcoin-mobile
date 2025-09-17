part of 'pay_bloc.dart';

@freezed
sealed class PayState with _$PayState {
  const factory PayState.recipientInput({
    UserSummary? userSummary,
    @Default([]) List<Recipient> recipients,
    //Recipient? selectedRecipient,
    @Default(false) bool isCreatingPayOrder,
    @Default(false) bool isCreatingNewRecipient,
    @Default([]) List<CadBiller> cadBillers,
    @Default(false) bool isLoadingCadBillers,
    @Default(false) bool isLoadingRecipients,
    PayError? error,
  }) = PayRecipientInputState;
  const factory PayState.amountInput({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required Recipient selectedRecipient,
  }) = PayAmountInputState;
  const factory PayState.walletSelection({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required Recipient selectedRecipient,
    required FiatAmount amount,
    @Default(false) bool isCreatingPayOrder,
    PayError? error,
  }) = PayWalletSelectionState;
  const factory PayState.payment({
    required UserSummary userSummary,
    required List<Recipient> recipients,
    required Recipient selectedRecipient,
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
      recipientInput: (userSummary, _, _, _, _, _, _, _) => userSummary,
      amountInput: (userSummary, _, _) => userSummary,
      walletSelection: (userSummary, _, _, _, _, _) => userSummary,
      payment:
          (userSummary, _, _, _, _, _, _, _, _, _, _, _, _, _) => userSummary,
      success: (_) => null,
    );
  }

  FiatCurrency get currency {
    return when(
      recipientInput:
          (userSummary, _, _, _, _, _, _, _) =>
              userSummary != null
                  ? FiatCurrency.fromCode(
                    userSummary.currency ?? FiatCurrency.cad.code,
                  )
                  : FiatCurrency.cad,
      amountInput:
          (_, _, selectedRecipient) => FiatCurrency.fromCode(
            selectedRecipient.recipientType.currencyCode,
          ),
      walletSelection:
          (_, _, selectedRecipient, _, _, _) => FiatCurrency.fromCode(
            selectedRecipient.recipientType.currencyCode,
          ),
      payment:
          (_, _, _, _, _, payOrder, _, _, _, _, _, _, _, _) =>
              FiatCurrency.fromCode(payOrder.payoutCurrency),
      success: (order) => FiatCurrency.fromCode(order.payoutCurrency),
    );
  }

  List<Recipient> get recipients {
    return when(
      amountInput: (_, recipients, _) => recipients,
      recipientInput: (_, recipients, _, _, _, _, _, _) => recipients,
      walletSelection: (_, recipients, _, _, _, _) => recipients,
      payment:
          (_, recipients, _, _, _, _, _, _, _, _, _, _, _, _) => recipients,
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
          (userSummary, recipients, selectedRecipient) => PayAmountInputState(
            userSummary: userSummary,
            recipients: recipients,
            selectedRecipient: selectedRecipient,
          ),
      walletSelection:
          (userSummary, recipients, selectedRecipient, _, _, _) =>
              PayAmountInputState(
                userSummary: userSummary,
                recipients: recipients,
                selectedRecipient: selectedRecipient,
              ),
      payment:
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
            _,
            _,
            _,
            _,
            _,
          ) => PayAmountInputState(
            userSummary: userSummary,
            recipients: recipients,
            selectedRecipient: selectedRecipient,
          ),
    );
  }

  PayRecipientInputState? get cleanRecipientInputState {
    return whenOrNull(
      recipientInput:
          (userSummary, recipients, _, _, _, _, _, _) => PayRecipientInputState(
            userSummary: userSummary,
            recipients: recipients,
          ),
      amountInput:
          (userSummary, recipients, _) => PayRecipientInputState(
            userSummary: userSummary,
            recipients: recipients,
          ),
      walletSelection:
          (userSummary, recipients, _, _, _, _) => PayRecipientInputState(
            userSummary: userSummary,
            recipients: recipients,
          ),
      payment:
          (userSummary, recipients, _, _, _, _, _, _, _, _, _, _, _, _) =>
              PayRecipientInputState(
                userSummary: userSummary,
                recipients: recipients,
              ),
    );
  }

  PayWalletSelectionState? get cleanWalletSelectionState {
    return whenOrNull(
      walletSelection:
          (userSummary, recipients, selectedRecipient, amount, _, _) =>
              PayWalletSelectionState(
                userSummary: userSummary,
                recipients: recipients,
                selectedRecipient: selectedRecipient,
                amount: amount,
              ),
      payment:
          (
            userSummary,
            recipients,
            selectedRecipient,
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
            userSummary: userSummary,
            recipients: recipients,
            selectedRecipient: selectedRecipient,
            amount: amount,
          ),
    );
  }

  PayPaymentState? get cleanPaymentState {
    return whenOrNull(
      payment:
          (
            userSummary,
            recipients,
            selectedRecipient,
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
            userSummary: userSummary,
            recipients: recipients,
            selectedRecipient: selectedRecipient,
            amount: amount,
            selectedWallet: selectedWallet,
            payOrder: payOrder,
          ),
    );
  }
}

extension PayRecipientInputStateX on PayRecipientInputState {
  PayAmountInputState toAmountInputState({required Recipient recipient}) {
    if (userSummary == null) {
      throw StateError('Cannot create amount input state without user summary');
    }

    return PayAmountInputState(
      userSummary: userSummary!,
      recipients: recipients,
      selectedRecipient: recipient,
    );
  }
}

extension PayAmountInputStateX on PayAmountInputState {
  PayWalletSelectionState toWalletSelectionState({required FiatAmount amount}) {
    return PayWalletSelectionState(
      userSummary: userSummary,
      recipients: recipients,
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
      recipients: recipients,
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
      recipients: recipients,
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
