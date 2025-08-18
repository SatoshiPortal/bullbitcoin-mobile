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
        _,
        _,
        _,
        _,
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
            _,
            _,
            _,
            _,
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
        _,
        _,
        _,
        _,
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
            _,
            _,
            _,
            _,
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
            _,
            _,
            _,
            _,
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
