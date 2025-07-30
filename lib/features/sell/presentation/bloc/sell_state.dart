part of 'sell_bloc.dart';

@freezed
sealed class SellState with _$SellState {
  const factory SellState.initial({
    ApiKeyException? apiKeyException,
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
    SellError? error,
    int? absoluteFees,
  }) = SellPaymentState;
  const factory SellState.success({required SellOrder sellOrder}) =
      SellSuccessState;
  const SellState._();
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
  SellAmountInputState toAmountInputState() {
    return SellAmountInputState(
      userSummary: userSummary,
      bitcoinUnit: bitcoinUnit,
    );
  }

  SellPaymentState toSendPaymentState({
    required Wallet selectedWallet,
    required SellOrder createdSellOrder,
    int? absoluteFees,
  }) {
    return SellPaymentState(
      userSummary: userSummary,
      bitcoinUnit: bitcoinUnit,
      orderAmount: orderAmount,
      fiatCurrency: fiatCurrency,
      selectedWallet: selectedWallet,
      sellOrder: createdSellOrder,
      absoluteFees: absoluteFees,
    );
  }

  SellPaymentState toReceivePaymentState({
    required SellOrder createdSellOrder,
  }) {
    return SellPaymentState(
      userSummary: userSummary,
      bitcoinUnit: bitcoinUnit,
      orderAmount: orderAmount,
      fiatCurrency: fiatCurrency,
      sellOrder: createdSellOrder,
    );
  }
}

extension SellPaymentStateX on SellPaymentState {
  SellWalletSelectionState toWalletSelectionState() {
    return SellWalletSelectionState(
      userSummary: userSummary,
      bitcoinUnit: bitcoinUnit,
      orderAmount: orderAmount,
      fiatCurrency: fiatCurrency,
    );
  }

  SellSuccessState toSuccessState({required SellOrder sellOrder}) {
    return SellSuccessState(sellOrder: sellOrder);
  }

  String get bip21InvoiceData {
    final order = sellOrder;
    String invoiceString = '';

    switch (order.payinMethod) {
      case OrderPaymentMethod.bitcoin:
        if (order.bitcoinAddress != null) {
          final amountBtc = order.payinAmount;
          final address = order.bitcoinAddress!;

          final bip21Uri = Uri(
            scheme: 'bitcoin',
            path: address,
            queryParameters: {'amount': amountBtc.toString()},
          );
          invoiceString = bip21Uri.toString();
        }
      case OrderPaymentMethod.liquid:
        if (order.liquidAddress != null) {
          final amountBtc = order.payinAmount;
          final address = order.liquidAddress!;

          final bip21Uri = Uri(
            scheme: 'liquidnetwork',
            path: address,
            queryParameters: {
              'amount': amountBtc.toString(),
              'assetid': AssetConstants.lbtcMainnet,
            },
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
