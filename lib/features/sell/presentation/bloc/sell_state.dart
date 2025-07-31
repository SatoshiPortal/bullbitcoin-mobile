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
    @Default(false) bool isPolling,
    SellError? error,
    int? absoluteFees,
  }) = SellPaymentState;
  const factory SellState.success({
    required BitcoinUnit bitcoinUnit,
    required SellOrder sellOrder,
  }) = SellSuccessState;
  const SellState._();

  SellAmountInputState? get toCleanAmountInputState {
    return whenOrNull(
      amountInput: (userSummary, bitcoinUnit) {
        return SellAmountInputState(
          userSummary: userSummary,
          bitcoinUnit: bitcoinUnit,
        );
      },
      walletSelection: (
        userSummary,
        bitcoinUnit,
        orderAmount,
        fiatCurrency,
        isCreatingSellOrder,
        error,
      ) {
        return SellAmountInputState(
          userSummary: userSummary,
          bitcoinUnit: bitcoinUnit,
        );
      },
      payment: (
        userSummary,
        bitcoinUnit,
        orderAmount,
        fiatCurrency,
        selectedWallet,
        sellOrder,
        isConfirmingPayment,
        isPolling,
        error,
        absoluteFees,
      ) {
        return SellAmountInputState(
          userSummary: userSummary,
          bitcoinUnit: bitcoinUnit,
        );
      },
    );
  }

  SellWalletSelectionState? get toCleanWalletSelectionState {
    return whenOrNull(
      walletSelection: (
        userSummary,
        bitcoinUnit,
        orderAmount,
        fiatCurrency,
        isCreatingSellOrder,
        error,
      ) {
        return SellWalletSelectionState(
          userSummary: userSummary,
          bitcoinUnit: bitcoinUnit,
          orderAmount: orderAmount,
          fiatCurrency: fiatCurrency,
        );
      },
      payment:
          (
            userSummary,
            bitcoinUnit,
            orderAmount,
            fiatCurrency,
            selectedWallet,
            sellOrder,
            isConfirmingPayment,
            isPolling,
            error,
            absoluteFees,
          ) => SellWalletSelectionState(
            userSummary: userSummary,
            bitcoinUnit: bitcoinUnit,
            orderAmount: orderAmount,
            fiatCurrency: fiatCurrency,
          ),
    );
  }

  SellPaymentState? get toCleanPaymentState {
    return whenOrNull(
      payment: (
        userSummary,
        bitcoinUnit,
        orderAmount,
        fiatCurrency,
        selectedWallet,
        sellOrder,
        isConfirmingPayment,
        isPolling,
        error,
        absoluteFees,
      ) {
        return SellPaymentState(
          userSummary: userSummary,
          bitcoinUnit: bitcoinUnit,
          orderAmount: orderAmount,
          fiatCurrency: fiatCurrency,
          selectedWallet: selectedWallet,
          sellOrder: sellOrder,
          absoluteFees: absoluteFees,
        );
      },
    );
  }

  FiatCurrency get fiatCurrency {
    return when(
      initial: (apiKeyException, getUserSummaryException) => FiatCurrency.cad,
      amountInput:
          (userSummary, bitcoinUnit) =>
              FiatCurrency.fromCode(userSummary.currency ?? 'CAD'),
      walletSelection:
          (
            userSummary,
            bitcoinUnit,
            orderAmount,
            fiatCurrency,
            isCreatingSellOrder,
            error,
          ) => fiatCurrency,
      payment:
          (
            userSummary,
            bitcoinUnit,
            orderAmount,
            fiatCurrency,
            selectedWallet,
            sellOrder,
            isConfirmingPayment,
            isPolling,
            error,
            absoluteFees,
          ) => fiatCurrency,
      success:
          (bitcoinUnit, sellOrder) =>
              FiatCurrency.fromCode(sellOrder.payoutCurrency),
    );
  }

  BitcoinUnit? get bitcoinUnit {
    return when(
      initial: (apiKeyException, getUserSummaryException) => null,
      amountInput: (userSummary, bitcoinUnit) => bitcoinUnit,
      walletSelection:
          (
            userSummary,
            bitcoinUnit,
            orderAmount,
            fiatCurrency,
            isCreatingSellOrder,
            error,
          ) => bitcoinUnit,
      payment:
          (
            userSummary,
            bitcoinUnit,
            orderAmount,
            fiatCurrency,
            selectedWallet,
            sellOrder,
            isConfirmingPayment,
            isPolling,
            error,
            absoluteFees,
          ) => bitcoinUnit,
      success: (bitcoinUnit, sellOrder) => bitcoinUnit,
    );
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
