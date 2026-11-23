part of 'pay_bloc.dart';

@freezed
sealed class PayState with _$PayState {
  const factory PayState.recipientSelection({
    UserSummary? userSummary,
    @Default(false) bool isLoadingUserSummary,
    PayFailure? error,
  }) = PayRecipientSelectionState;
  const factory PayState.amountInput({
    required RecipientViewModel selectedRecipient,
    required UserSummary userSummary,
    PayFailure? error,
  }) = PayAmountInputState;
  const factory PayState.walletSelection({
    required RecipientViewModel selectedRecipient,
    required UserSummary userSummary,
    required FiatAmount amount,
    String? paymentDescription,
    @Default(false) bool isCreatingPayOrder,
    PayFailure? error,
  }) = PayWalletSelectionState;
  const factory PayState.preparingPayment({
    required PayWalletSelectionState input,
    ExchangePayinWallet? selectedWallet,
    PayFailure? error,
  }) = PayPreparingPaymentState;
  const factory PayState.payment({
    required RecipientViewModel selectedRecipient,
    required UserSummary userSummary,
    required FiatAmount amount,
    String? paymentDescription,
    ExchangePayinWallet? selectedWallet,
    required FiatPaymentOrder payOrder,
    @Default(false) bool isConfirmingPayment,
    PayjoinSenderSession? pausedPayjoinSession,
    @Default(false) bool isRetryingPayjoinProposal,
    @Default(false) bool isPolling,
    // Txid of the payin transaction once it is on the wire. Acts as a latch:
    // the send path must never run again for this order (#2522).
    String? payinBroadcastTxid,
    // Set once the exchange reports, after the payin was broadcast, that the
    // order's payment deadline expired before it saw the payment. The latch
    // above stays: the order is paid as far as this device is concerned.
    @Default(false) bool isPayinPastDeadline,
    // Set with the latch when the broadcast failed in a way that may still
    // have put the payin on the network: the flow verifies it against the
    // order instead of re-arming Confirm.
    @Default(false) bool isPayinOutcomeUnknown,
    PayFailure? error,
    int? absoluteFees,
    @Default([]) List<Coin> utxos,
    @Default([]) List<Coin> selectedUtxos,
    @Default(true) bool replaceByFee,
    @Default(true) bool isPayjoinEnabled,
    double? exchangeRateEstimate,
    // Bitcoin fee selection (#2521), mirroring SellPaymentState: the payin is
    // built at the rate picked in the shared fee modal, not a hardcoded
    // Fastest.
    FeeOptions? bitcoinFees,
    NetworkFee? customFee,
    @Default(FeeSelection.fastest) FeeSelection selectedFeeOption,
    // Arm/disarm snapshot for the custom-fee field: typing commits `custom` so
    // the preset tiles deselect, and dismissal either finalizes the value or
    // rolls back to these. Internal to the modal flow; the UI must not read
    // them.
    FeeSelection? armPriorSelection,
    NetworkFee? armPriorCustomFee,
    // Real fees read from unsigned PSBTs, one slot per tier, so the modal never
    // shows rate × vsize arithmetic. Display only: the confirmation rebuilds
    // the payin at the committed rate rather than broadcasting a cached PSBT,
    // because a price-lock refresh can move the payin amount.
    @Default(BitcoinFeePreviewCache.empty)
    BitcoinFeePreviewCache feePreviewCache,
    // vsize of the last payin build — needed to express an absolute custom fee
    // as a rate for the relay-floor checks.
    int? bitcoinTxSize,
  }) = PayPaymentState;
  const factory PayState.success({required FiatPaymentOrder payOrder}) =
      PaySuccessState;
  const PayState._();

  UserSummary? get userSummary => switch (this) {
    PayRecipientSelectionState(:final userSummary) => userSummary,
    PayAmountInputState(:final userSummary) => userSummary,
    PayPreparingPaymentState(:final input) => input.userSummary,
    PayWalletSelectionState(:final userSummary) => userSummary,
    PayPaymentState(:final userSummary) => userSummary,
    PaySuccessState() => null,
  };

  bool get isFullyVerifiedKycLevel =>
      userSummary?.isFullyVerifiedKycLevel == true;

  bool get isLimitedKycLevel => userSummary?.isLimitedKycLevel == true;

  bool get isLightKycLevel => userSummary?.isLightKycLevel == true;

  bool needsKycUpgrade(double amount, {FiatCurrency? currency}) {
    final summary = userSummary;
    if (summary == null) return true;
    final effectiveCurrency = currency ?? this.currency;
    return ExchangeCatalog.market(effectiveCurrency).kyc
        .needsUpgrade(summary.kycGroups, amount);
  }

  FiatCurrency get currency => switch (this) {
    PayRecipientSelectionState(:final userSummary) =>
      userSummary?.currency != null
          ? FiatCurrency.fromCode(userSummary!.currency!)
          : ExchangeCatalog.legacyNoMarketFallback.currency,
    PayAmountInputState(:final selectedRecipient) => FiatCurrency.fromCode(
      selectedRecipient.currencyCode,
    ),
    PayPreparingPaymentState(:final input) => input.currency,
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
  PayRecipientSelectionState? get cleanRecipientSelectionState =>
      switch (this) {
        final PayRecipientSelectionState s => s.copyWith(
          isLoadingUserSummary: false,
          error: null,
        ),
        PayAmountInputState(:final userSummary) => PayRecipientSelectionState(
          userSummary: userSummary,
        ),
        PayPreparingPaymentState(:final input) =>
          input.cleanRecipientSelectionState,
        PayWalletSelectionState(:final userSummary) =>
          PayRecipientSelectionState(userSummary: userSummary),
        PayPaymentState(:final userSummary) => PayRecipientSelectionState(
          userSummary: userSummary,
        ),
        PaySuccessState() => null,
      };

  PayAmountInputState? get cleanAmountInputState => switch (this) {
    final PayAmountInputState s => s.copyWith(error: null),
    PayPreparingPaymentState(:final input) => input.cleanAmountInputState,
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
    PayPreparingPaymentState(:final input) => input.cleanWalletSelectionState,
    final PayWalletSelectionState s => s.copyWith(
      isCreatingPayOrder: false,
      error: null,
    ),
    PayPaymentState(
      :final selectedRecipient,
      :final userSummary,
      :final amount,
      :final paymentDescription,
    ) =>
      PayWalletSelectionState(
        selectedRecipient: selectedRecipient,
        userSummary: userSummary,
        amount: amount,
        paymentDescription: paymentDescription,
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
    final summary = userSummary;
    if (summary == null) {
      throw StateError('Cannot create amount input state without user summary');
    }

    return PayAmountInputState(
      selectedRecipient: selectedRecipient,
      userSummary: summary,
    );
  }
}

extension PayAmountInputStateX on PayAmountInputState {
  PayWalletSelectionState toWalletSelectionState({
    required FiatAmount amount,
    String? paymentDescription,
  }) {
    return PayWalletSelectionState(
      userSummary: userSummary,
      amount: amount,
      selectedRecipient: selectedRecipient,
      paymentDescription: paymentDescription,
      isCreatingPayOrder: false,
    );
  }
}

extension PayWalletSelectionStateX on PayWalletSelectionState {
  PayPaymentState toSendPaymentState({
    required ExchangePayinWallet selectedWallet,
    required FiatPaymentOrder payOrder,
    List<Coin>? utxos,
    int? absoluteFees,
    double? exchangeRateEstimate,
    FeeOptions? bitcoinFees,
    int? bitcoinTxSize,
    PayFailure? error,
  }) {
    return PayPaymentState(
      userSummary: userSummary,
      amount: amount,
      selectedRecipient: selectedRecipient,
      paymentDescription: paymentDescription,
      selectedWallet: selectedWallet,
      payOrder: payOrder,
      absoluteFees: absoluteFees,
      exchangeRateEstimate: exchangeRateEstimate,
      utxos: utxos ?? [],
      bitcoinFees: bitcoinFees,
      bitcoinTxSize: bitcoinTxSize,
      error: error,
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
      paymentDescription: paymentDescription,
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
  bool get isPayinBroadcast => payinBroadcastTxid != null;

  /// Leaving is safe before the confirmation starts, and after the broadcast
  /// only once the exchange has reported the payin late: until then the screen
  /// is what takes the order to success. The broadcast latch survives leaving
  /// and still forbids paying this order again.
  bool get canLeavePaymentScreen =>
      !isConfirmingPayment && (!isPayinBroadcast || isPayinPastDeadline);

  /// Fee the payin must be built at, resolved from the committed selection.
  /// Null while the presets have not loaded (or custom was selected with no
  /// value) — the caller decides, rather than silently reverting to Fastest,
  /// which is the bug #2521 describes.
  NetworkFee? get selectedFee => switch (selectedFeeOption) {
    FeeSelection.fastest => bitcoinFees?.fastest,
    FeeSelection.economic => bitcoinFees?.economic,
    FeeSelection.slow => bitcoinFees?.slow,
    FeeSelection.custom => customFee,
  };

  /// Fee selection is only editable before the confirmation starts: the
  /// transaction on its way to the network was built at the committed rate, so
  /// rebuilding under it would pay a different fee than the one shown. Liquid
  /// payins have no fee choice at all.
  bool get canEditFees =>
      !isConfirmingPayment &&
      !isPayinBroadcast &&
      selectedWallet?.isLiquid == false;

  String get bip21InvoiceData {
    final order = payOrder;
    String invoiceString = '';

    switch (order.payinMethod) {
      case OrderPaymentMethod.bitcoin:
        if (order.bitcoinAddress case final String address) {
          final amountBtc = order.payinAmount;

          final bip21Uri = Bip21Uri(
            scheme: 'bitcoin',
            address: address,
            amount: amountBtc,
          );
          invoiceString = bip21Uri.toString();
        }
      case OrderPaymentMethod.liquid:
        if (order.liquidAddress case final String address) {
          final amountBtc = order.payinAmount;

          final bip21Uri = Bip21Uri(
            scheme: 'liquidnetwork',
            address: address,
            amount: amountBtc,
            options: {'assetid': lbtcMainnetAssetId},
          );
          invoiceString = bip21Uri.toString();
        }
      case OrderPaymentMethod.lnInvoice:
        if (order.lightningInvoice case final String invoice) {
          invoiceString = invoice;
        }
      default:
        break;
    }

    return invoiceString;
  }
}
