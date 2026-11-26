part of 'send_screen.dart';

/// Owns ephemeral mono UI state; transaction intent remains in SendCubit.
final class _SendPaymentSession {
  _SendPaymentSession(this.cubit, this.confirm, this.startMultipleRecipients)
    : amountController = TextEditingController(text: cubit.state.amount),
      unit = ValueNotifier(cubit.state.bitcoinUnit ?? BitcoinUnit.btc);
  final SendCubit cubit;
  final Future<void> Function() confirm;

  /// Hands over to the classic recipient screen, which owns several recipients.
  final VoidCallback startMultipleRecipients;
  final TextEditingController amountController;
  final FocusNode amountFocus = FocusNode();
  final ValueNotifier<BitcoinUnit> unit;
  int _inputRevision = 0;
  bool _openingCoins = false;
  bool _disposed = false;
  bool _initializedUnit = false;
  String _canonicalText = '';

  void dispose() {
    _disposed = true;
    _inputRevision++;
    amountController.dispose();
    amountFocus.dispose();
    unit.dispose();
  }

  bool supports(SendState state) {
    final fixedInvoice =
        state.paymentRequest is Bolt11PaymentRequest &&
        state.hasFixedRequestAmount;
    if (fixedInvoice) {
      return !cubit.isSpMode &&
          !state.isSweep &&
          !state.usesSelectedInputsOnly &&
          !state.hasMultipleRecipients &&
          (state.step == SendStep.address || state.step == SendStep.amount);
    }
    if (cubit.isSpMode ||
        state.isSweep ||
        state.usesSelectedInputsOnly ||
        state.hasMultipleRecipients ||
        state.hasFixedRequestAmount ||
        state.selectedWallet?.isHardwareWallet == true ||
        state.selectedWallet?.signsLocally == false ||
        state.isPayjoinAvailable) {
      return false;
    }
    final request = state.paymentRequest;
    final liquidRequest =
        request is LiquidPaymentRequest ||
        (request is Bip21PaymentRequest &&
            request.network is chains.LiquidNetwork);
    if (state.step == SendStep.address && liquidRequest) return true;
    if (state.selectedWallet?.isLiquid == true) {
      return state.sendType == SendType.liquid && liquidRequest;
    }
    return request == null ||
        const BitcoinRecipientListPolicy().isPlainAddress(request);
  }

  bool supportsLiquidReview(SendState state) =>
      _isPlainLiquidPayment(state, spMode: cubit.isSpMode);

  /// Several recipients paid by a wallet that signs here confirm on the same
  /// review. Hardware wallets and coin control keep the classic screen.
  bool supportsMultipleReview(SendState state) =>
      !cubit.isSpMode &&
      state.hasMultipleRecipients &&
      state.selectedWallet?.isLiquid == false &&
      state.selectedWallet?.signsLocally == true &&
      state.selectedWallet?.isHardwareWallet == false &&
      state.selectedUtxos.isEmpty &&
      !state.usesSelectedInputsOnly &&
      !state.isSweep;

  void update(SendState state) {
    if (_canonicalText == state.amount) return;
    _canonicalText = state.amount;
    amountController.value = TextEditingValue(
      text: state.amount,
      selection: TextSelection.collapsed(offset: state.amount.length),
    );
  }

  Future<void> input(String text) async {
    final revision = ++_inputRevision;
    await cubit.onChangedText(text);
    if (_disposed ||
        revision != _inputRevision ||
        !supports(cubit.state) ||
        !cubit.state.hasValidPaymentRequest ||
        cubit.state.failure != null) {
      return;
    }
    await _toAmount(revision);
  }

  /// Confirms the recipient already entered, as after Edit, where nothing is typed again.
  Future<void> confirmRecipient() => _toAmount(++_inputRevision);

  Future<void> _toAmount(int revision) async {
    await cubit.continueOnAddressConfirmed();
    if (_disposed ||
        revision != _inputRevision ||
        cubit.state.step != SendStep.amount) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && revision == _inputRevision) amountFocus.requestFocus();
    });
  }

  Future<void> scan(String raw) async {
    final revision = ++_inputRevision;
    await cubit.onScannedPaymentRequest(raw);
    if (!_disposed &&
        revision == _inputRevision &&
        supports(cubit.state) &&
        cubit.state.step == SendStep.amount) {
      amountFocus.requestFocus();
    }
  }

  void edit() {
    _inputRevision++;
    amountFocus.unfocus();
    cubit.backClicked();
  }

  List<String> steps(BuildContext context) => [
    context.loc.sendRecipient,
    context.loc.sendAmount,
    context.loc.sendConfirm,
  ];

  String feeName(BuildContext context, FeeSelection selection) =>
      switch (selection) {
        FeeSelection.fastest => context.loc.sendFastFee,
        FeeSelection.economic => context.loc.sendEconomyFee,
        FeeSelection.slow => context.loc.feePrioritySlow,
        FeeSelection.custom => context.loc.sendFeeCustom,
      };

  /// How long a custom fee takes, read against the current presets.
  String customFeeTime(BuildContext context, SendState state, int? satPerKwu) {
    final presets = state.bitcoinFeesList;
    if (presets == null || satPerKwu == null) return '';
    int? rate(NetworkFee fee) => fee is RelativeFee ? fee.satPerKwu : null;
    if (rate(presets.fastest) case final fastest? when satPerKwu >= fastest) {
      return context.loc.sendFeeTimeFast;
    }
    if (rate(presets.economic) case final economic?
        when satPerKwu >= economic) {
      return context.loc.sendEstimatedDelivery10to30Minutes;
    }
    return context.loc.sendEstimatedDeliveryHours;
  }

  String feeTime(BuildContext context, FeeSelection selection) =>
      switch (selection) {
        FeeSelection.fastest => context.loc.sendFeeTimeFast,
        FeeSelection.economic => context.loc.sendEstimatedDelivery10to30Minutes,
        FeeSelection.slow => context.loc.sendEstimatedDeliveryHours,
        FeeSelection.custom => '',
      };

  Widget money(
    BuildContext context,
    int sats, {
    TextStyle? style,
    bool negative = false,
  }) => ValueListenableBuilder<BitcoinUnit>(
    valueListenable: unit,
    builder: (_, value, _) => Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => unit.value = value == BitcoinUnit.btc
            ? BitcoinUnit.sats
            : BitcoinUnit.btc,
        child: Text(
          '${negative ? '− ' : ''}${value == BitcoinUnit.sats ? FormatAmount.sats(sats) : '${Sats.fromInt(sats).toBitcoinText(value)} ${value.code}'}',
          textAlign: TextAlign.end,
          style: (style ?? context.bullType.body).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );

  String fiat(SendState state, int sats) {
    final rate = state.exchangeRate;
    return rate == null
        ? ''
        : '≈ ${(sats / 100000000 * rate).toStringAsFixed(2)} ${state.fiatCurrencyCode}';
  }

  Widget build(BuildContext context, SendState state) {
    if (!_initializedUnit) {
      unit.value =
          state.bitcoinUnit ??
          BullAmountScope.maybeOf(context)?.snapshot.unit ??
          BitcoinUnit.btc;
      _initializedUnit = true;
    }
    if (state.step == SendStep.confirm) return review(context, state);
    final ready = state.step == SendStep.amount;
    final fixedInvoice =
        state.paymentRequest is Bolt11PaymentRequest &&
        state.hasFixedRequestAmount;
    final busy =
        state.loadingBestWallet ||
        state.buildingTransaction ||
        state.amountConfirmedClicked ||
        state.creatingSwap;
    final eligible = fixedInvoice
        ? const FixedAmountWalletChoicePolicy()
              .eligibleWallets(
                state.paymentRequest as Bolt11PaymentRequest,
                state.wallets,
              )
              .where((source) => !source.isHardwareWallet)
              .toList()
        : <SendSource>[];
    final wallet = state.selectedWallet;
    final canonical =
        BitcoinUnit.values
            .where((v) => v.code == state.inputAmountCurrencyCode)
            .firstOrNull ??
        BitcoinUnit.btc;
    return SendPaymentPage(
      title: context.loc.sendTitle,
      stepLabels: steps(context),
      stepSemanticLabel: (i, label) => '${i + 1}: $label',
      recipientLabel: context.loc.sendTo,
      recipient: ready
          ? BullBorderedTile(
              onTap: null,
              // The text inset of the other fields; the edit action keeps
              // the field's own small end inset.
              padding: const EdgeInsetsDirectional.only(
                start: BullSpacing.md,
                top: BullSpacing.xs,
                end: BullSpacing.xs,
                bottom: BullSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AddressViewer(
                      state.paymentRequestAddress,
                      clipboardText: state.copiedRawPaymentRequest,
                      style: context.bullType.body,
                    ),
                  ),
                  const Gap(BullSpacing.sm),
                  BullFieldAction(
                    icon: BullIcons.edit,
                    label: context.loc.sendEdit,
                    onPressed: busy ? null : edit,
                  ),
                ],
              ),
            )
          : AddressField(onInput: input, onScanned: scan, showLabel: false),
      amountLabel: context.loc.sendAmount,
      amount: fixedInvoice
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BullBorderedTile(
                  child: money(context, state.effectiveAmountSat),
                ),
                if (state.failure case final failure?) ...[
                  const Gap(BullSpacing.xs),
                  Text(
                    failure.toTranslated(
                      context,
                      formattedFrozenBalance: state.frozenBalanceHint,
                    ),
                    style: context.bullType.body.copyWith(
                      color: context.bull.error,
                    ),
                  ),
                ],
              ],
            )
          : ValueListenableBuilder<BitcoinUnit>(
              valueListenable: unit,
              builder: (_, displayUnit, _) => BullAmountInput(
                inCard: true,
                framed: true,
                canonicalUnit: canonical,
                bitcoinDisplayUnit: displayUnit,
                onBitcoinUnitChanged: (value) => unit.value = value,
                amountController: amountController,
                focusNode: amountFocus,
                defaultCurrencyCode: state.fiatCurrencyCode,
                currencies: [
                  for (final currency in SupportedCurrency.values)
                    BullAmountCurrency(
                      code: currency.code,
                      decimals: currency.decimals,
                      price: state.amountQuotes[currency]?.fiatAmount,
                      priceAt: state.amountQuotes[currency]?.fetchedAt,
                    ),
                ],
                onEntryChanged: (entry) => cubit.amountEntryChanged(
                  sats: entry.sats,
                  currencyCode: entry.currencyCode,
                  text: entry.text,
                  rate: entry.price,
                  quotedAt: entry.priceAt,
                  isValid: entry.isValid,
                  isEdit: entry.isEdit,
                ),
                isLiquid: wallet?.isLiquid == true,
                isMax: state.isMaxSend,
                maxLoading:
                    state.isMaxSend && cubit.preparedMaxAmountSat == null,
                maxAmountSat: switch (cubit.preparedMaxAmountSat) {
                  final n? => BigInt.from(n),
                  null => null,
                },
                error: state.failure?.toTranslated(
                  context,
                  formattedFrozenBalance: state.frozenBalanceHint,
                ),
              ),
            ),
      balance: Wrap(
        spacing: BullSpacing.xxs,
        children: [
          Text(
            context.loc.sendBalance,
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          ),
          money(
            context,
            state.maxAvailableBalanceSat,
            style: context.bullType.body,
          ),
        ],
      ),
      fromLabel: context.loc.sendFrom,
      wallet: BullDropdown<String>(
        value: wallet?.id,
        items: [
          for (final source in walletChoices(state))
            BullPickerItem(
              value: source.id,
              label: source.displayLabel(context),
            ),
        ],
        onChanged:
            ready &&
                !busy &&
                (!fixedInvoice ||
                    eligible.length > 1 ||
                    (eligible.length == 1 && eligible.single.id != wallet?.id))
            ? selectWallet
            : null,
      ),
      maxLabel: context.loc.swapMax,
      settingsLabel: context.loc.sendAdvancedSettings,
      extra: state.consolidationRequired && wallet != null
          ? BullAlertCard(
              title: context.loc.consolidationRequiredTitle,
              onTap: () => context.pushNamed(
                ConsolidationRoute.consolidation.name,
                pathParameters: {'walletId': wallet.id},
              ),
            )
          : null,
      continueLabel: context.loc.sendContinue,
      recipientReady: ready,
      isBusy: busy,
      showMax: !fixedInvoice,
      showSettings: !fixedInvoice,
      onBack: () {
        if (busy) return;
        if (ready) {
          edit();
        } else {
          context.pop();
        }
      },
      onSettings: () => wallet?.isLiquid == true
          ? liquidSettings(context)
          : settings(context),
      onMax: ready
          ? wallet?.isLiquid == true
                ? () => cubit.amountChanged(
                    amount: state.isMaxSend ? amountController.text : null,
                    isMax: !state.isMaxSend,
                  )
                : () => max(context)
          : null,
      onContinue: !ready
          ? (state.hasValidPaymentRequest && state.failure == null && !busy
                ? confirmRecipient
                : null)
          : state.effectiveAmountSat > 0 &&
                state.hasValidAmountEntry &&
                (fixedInvoice || state.failure == null) &&
                (!fixedInvoice ||
                    eligible.any((source) => source.id == wallet?.id)) &&
                !state.amountConfirmedClicked &&
                !state.creatingSwap &&
                !state.buildingTransaction
          ? () {
              amountFocus.unfocus();
              cubit.onAmountConfirmed();
            }
          : null,
    );
  }

  /// The wallets the From dropdown offers: for a fixed-amount invoice, those
  /// that can pay it; otherwise every wallet the classic screen offers.
  List<SendSource> walletChoices(SendState state) {
    final request = state.paymentRequest;
    return request is Bolt11PaymentRequest && request.amountSat > 0
        ? const FixedAmountWalletChoicePolicy()
              .eligibleWallets(request, state.wallets)
              .where((source) => !source.isHardwareWallet)
              .toList()
        : state.selectableWallets;
  }

  Future<void> selectWallet(String id) async {
    amountFocus.unfocus();
    final request = cubit.state.paymentRequest;
    final selected = walletChoices(cubit.state)
        .where((source) => source.id == id)
        .firstOrNull;
    if (!_disposed &&
        selected != null &&
        !cubit.state.amountConfirmedClicked &&
        !cubit.state.creatingSwap &&
        cubit.state.step == SendStep.amount &&
        (request is! Bolt11PaymentRequest ||
            (cubit.state.paymentRequest == request &&
                const FixedAmountWalletChoicePolicy()
                    .eligibleWallets(request, cubit.state.wallets)
                    .any(
                      (source) =>
                          source.id == selected.id && !source.isHardwareWallet,
                    )))) {
      await cubit.updateSelectedWallet(selected);
    }
  }

  void liquidSettings(BuildContext context) {
    amountFocus.unfocus();
    BullBottomSheet.show(
      context: context,
      child: BlocProvider.value(
        value: cubit,
        child: const AdvancedOptionsBottomSheet(),
      ),
    );
  }

  Future<void> max(BuildContext context) async {
    amountFocus.unfocus();
    final preview = await cubit.previewMonoMax();
    if (_disposed || !context.mounted) return;
    if (preview == null) {
      BullSnackBar.show(context, message: context.loc.sendPaymentChanged);
      return;
    }
    final walletName = cubit.state.selectedWallet?.displayLabel(context) ?? '';
    final selected = preview.selectedCoins;
    final protected = preview.protectedCoinsRemain;
    final value = context.bullType.label.copyWith(fontWeight: FontWeight.w700);
    final accepted = await BullBottomSheet.show<bool>(
      context: context,
      child: Builder(
        builder: (sheetContext) => SendWholeBalanceDialog(
          title: selected
              ? context.loc.sendSelectedCoinsTitle
              : protected
              ? context.loc.sendAvailableBalanceTitle
              : context.loc.sendWholeBalanceTitle,
          description: selected
              ? context.loc.sendSelectedCoinsDescription(walletName)
              : protected
              ? context.loc.sendAvailableBalanceDescription(walletName)
              : context.loc.sendWholeBalanceDescription(walletName),
          balanceLabel: selected
              ? context.loc.sendSelectedCoinsLabel
              : context.loc.sendBalance,
          balance: money(context, preview.availableSat, style: value),
          feeLabel:
              '${context.loc.sendNetworkFees} · ${feeName(context, cubit.state.selectedFeeOption)}',
          fee: money(context, preview.feeSat, negative: true, style: value),
          receivesLabel: context.loc.sendRecipientGets,
          receives: money(
            context,
            preview.recipientSat,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          receivesEquivalent: switch (fiat(cubit.state, preview.recipientSat)) {
            '' => null,
            final text => text,
          },
          closeLabel: context.loc.sendClose,
          sendAllLabel: context.loc.sendAllAction,
          onClose: () => Navigator.pop(sheetContext, false),
          onSendAll: () => Navigator.pop(sheetContext, true),
        ),
      ),
    );
    if (!_disposed && accepted == true) {
      final applied = await cubit.acceptMonoMax(preview);
      if (!applied && context.mounted) {
        BullSnackBar.show(context, message: context.loc.sendPaymentChanged);
      }
    }
  }

  /// [multipleSwitch] false on the classic amount step, whose recipients are
  /// managed on its own recipient step.
  Future<void> settings(
    BuildContext context, {
    bool multipleSwitch = true,
  }) async {
    amountFocus.unfocus();
    cubit.requestPresetPreviews();
    var custom = false;
    var mode = SendFeeInputMode.rate;
    var raw = '';
    Timer? timer;
    var armed = false;
    int? previewSize;
    var previewSelection = cubit.state.selectedFeeOption;
    void cancelDraft() {
      timer?.cancel();
      if (!armed) return;
      cubit.disarmCustomFee();
      cubit.clearBitcoinFeePreviews();
      cubit.refreshMonoPreview();
      armed = false;
    }

    final openCoins = await BullBottomSheet.show<bool>(
      context: context,
      avoidKeyboard: true,
      child: StatefulBuilder(
        builder: (sheetContext, setLocal) => BlocBuilder<SendCubit, SendState>(
          bloc: cubit,
          builder: (_, state) {
            void openCustom() {
              previewSelection = state.selectedFeeOption;
              previewSize =
                  state.feePreviewCache
                      .slotFor(state.selectedFeeOption)
                      .txSize ??
                  state.bitcoinTxSize;
              final fee = state.selectedFee;
              raw = fee is AbsoluteFee
                  ? fee.sats.toString()
                  : fee is RelativeFee
                  ? fee.satPerVbyte.toString()
                  : '';
              mode = fee is AbsoluteFee
                  ? SendFeeInputMode.total
                  : SendFeeInputMode.rate;
              setLocal(() => custom = true);
            }

            if (!custom) {
              final real =
                  state.feePreviewCache
                      .slotFor(state.selectedFeeOption)
                      .feeSat ??
                  state.absoluteFees;
              final detail = feeDescription(context, state);
              return SendPaymentSettings(
                title: context.loc.sendAdvancedSettings,
                closeLabel: context.loc.sendClose,
                feeLabel: context.loc.sendNetworkFees,
                feeChoices: {
                  for (final fee in FeeSelection.values)
                    fee: feeName(context, fee),
                },
                selectedFee: state.selectedFeeOption,
                feeDetail: Wrap(
                  children: [
                    if (detail.isNotEmpty)
                      Text(detail, style: context.bullType.label),
                    if (real != null && detail.isNotEmpty)
                      Text(' · ', style: context.bullType.label),
                    if (real != null)
                      money(context, real, style: context.bullType.label),
                  ],
                ),
                editLabel: context.loc.sendEdit,
                rbfLabel: context.loc.sendReplaceByFeeActivated,
                replaceByFee: state.replaceByFee,
                multipleLabel: context.loc.sendMultipleRecipients,
                multipleRecipients: false,
                showMultipleRecipients: multipleSwitch,
                coinsLabel: context.loc.sendCoinsInstead,
                onClose: () => Navigator.pop(sheetContext),
                onFeeSelected: (selection) {
                  if (selection == FeeSelection.custom) {
                    openCustom();
                  } else {
                    cubit.feeOptionSelected(selection);
                  }
                },
                onReplaceByFee: (value) => cubit.replaceByFeeChanged(value),
                onMultipleRecipients: state.canAddRecipient
                    ? (_) {
                        Navigator.pop(sheetContext);
                        if (cubit.state.step != SendStep.address) edit();
                        startMultipleRecipients();
                      }
                    : null,
                // Coins belong to a wallet, picked once the address is in:
                // say so instead of a tap that does nothing.
                onCoins: state.selectedBitcoinWallet == null
                    ? () => BullSnackBar.show(
                        sheetContext,
                        message: context.loc.sendCoinsNeedRecipient,
                      )
                    : () async {
                        if (_openingCoins) return;
                        _openingCoins = true;
                        try {
                          final leave = await confirmLeave(context);
                          if (leave && sheetContext.mounted) {
                            Navigator.pop(sheetContext, true);
                          }
                        } finally {
                          _openingCoins = false;
                        }
                      },
                onCustomFeeEdit: state.selectedFeeOption == FeeSelection.custom
                    ? openCustom
                    : null,
              );
            }
            previewSize =
                (armed ? state.feePreviewCache.custom.txSize : null) ??
                state.feePreviewCache.slotFor(previewSelection).txSize ??
                previewSize;
            SendFeeEvaluation evaluate(String text) =>
                const SendCustomFeePolicy().evaluate(
                  text: text,
                  mode: mode,
                  minRelaySatPerKwu:
                      state.bitcoinFeesList?.minRelay.satPerKwu ?? 25,
                  vsize: previewSize,
                );
            NetworkFee? native(SendFeeEvaluation result) =>
                switch ((result.relativeSatPerKwu, result.absoluteSats)) {
                  (final rate?, _) => NetworkFee.relativeSatPerKwu(rate),
                  (_, final total?) => NetworkFee.absolute(total),
                  _ => null,
                };
            final evaluation = evaluate(raw);
            final error = switch (evaluation.error) {
              null || SendFeeInputError.incomplete => null,
              SendFeeInputError.belowMinimum =>
                mode == SendFeeInputMode.rate
                    ? context.loc.sendCustomMinimumRate(evaluation.minimumRate)
                    : context.loc.sendCustomMinimumTotal(
                        '${evaluation.minimumTotalSats}',
                        evaluation.minimumRate,
                      ),
              SendFeeInputError.sizeUnavailable =>
                context.loc.sendCustomSizeUnavailable,
              _ => context.loc.sendCustomInvalid,
            };
            // ≈ fiat · the other unit · how long it takes, like the presets.
            final rateMode = mode == SendFeeInputMode.rate;
            final feeSats = rateMode
                ? evaluation.estimatedSats?.toInt()
                : evaluation.absoluteSats;
            final effectiveSatPerKwu = rateMode
                ? evaluation.relativeSatPerKwu
                : switch ((evaluation.absoluteSats, previewSize)) {
                    (final sats?, final size?) when size > 0 =>
                      (sats * 250 / size).round(),
                    _ => null,
                  };
            final help = [
              if (feeSats case final sats?) fiat(state, sats),
              if (rateMode && feeSats != null)
                '≈ $feeSats ${context.loc.sendSats}'
              else if (!rateMode && evaluation.effectiveRate != null)
                '${evaluation.effectiveRateIsApproximate ? '≈ ' : ''}${evaluation.effectiveRate} ${context.loc.sendSatsPerVB}',
              customFeeTime(context, state, effectiveSatPerKwu),
            ].where((s) => s.isNotEmpty).join(' · ');
            return SendCustomFeeEditor(
              title: context.loc.sendCustomFee,
              backLabel: context.loc.sendBack,
              closeLabel: context.loc.sendClose,
              modes: {
                context.loc.sendCustomRateMode,
                context.loc.sendCustomTotalMode,
              },
              selectedMode: mode == SendFeeInputMode.rate
                  ? context.loc.sendCustomRateMode
                  : context.loc.sendCustomTotalMode,
              value: raw,
              unit: mode == SendFeeInputMode.rate
                  ? context.loc.sendSatsPerVB
                  : context.loc.sendSats,
              help: help,
              doneLabel: context.loc.sendDone,
              error: error,
              warning: evaluation.warnSubOne
                  ? context.loc.sendCustomSubOne
                  : null,
              onMode: (value) {
                cancelDraft();
                setLocal(() {
                  mode = value == context.loc.sendCustomRateMode
                      ? SendFeeInputMode.rate
                      : SendFeeInputMode.total;
                  raw = '';
                });
              },
              onChanged: (value) {
                timer?.cancel();
                setLocal(() => raw = value);
                final result = evaluate(value);
                final fee = native(result);
                if (result.isValid && fee != null) {
                  cubit.armCustomFee(fee);
                  armed = true;
                  timer = Timer(
                    const Duration(milliseconds: 250),
                    () => cubit.requestCustomFeePreview(fee),
                  );
                } else {
                  cancelDraft();
                }
              },
              onBack: () {
                cancelDraft();
                setLocal(() => custom = false);
              },
              onClose: () {
                cancelDraft();
                Navigator.pop(sheetContext);
              },
              onSubmit: evaluation.isValid
                  ? (submitted) {
                      final current = const SendCustomFeePolicy().evaluate(
                        text: submitted,
                        mode: mode,
                        minRelaySatPerKwu:
                            cubit.state.bitcoinFeesList?.minRelay.satPerKwu ??
                            25,
                        vsize:
                            cubit.state.feePreviewCache.custom.txSize ??
                            previewSize,
                      );
                      final fee = native(current);
                      if (!current.isValid || fee == null) return;
                      timer?.cancel();
                      // An unchanged editor can still have an older Custom PSBT.
                      cubit.armCustomFee(fee);
                      armed = false;
                      cubit.customFeesChanged(fee);
                      setLocal(() => custom = false);
                    }
                  : null,
            );
          },
        ),
      ),
    );
    timer?.cancel();
    if (custom && !_disposed) cancelDraft();
    if (openCoins == true && !_disposed && context.mounted) {
      final wallet = cubit.state.selectedBitcoinWallet;
      if (wallet != null) {
        SendPaymentUi.of(context).openCoins(context, wallet.key);
      }
    }
  }

  Future<bool> confirmLeave(BuildContext context) async {
    final state = cubit.state;
    if (state.copiedRawPaymentRequest.trim().isEmpty &&
        amountController.text.trim().isEmpty) {
      return true;
    }
    return await BullDialog.show<bool>(
          context: context,
          builder: (dialogContext) => SendLeavePaymentDialog(
            title: context.loc.sendLeavePaymentTitle,
            description: context.loc.sendLeavePaymentDescription,
            cancelLabel: context.loc.cancel,
            openLabel: context.loc.sendOpenCoins,
            onCancel: () => Navigator.pop(dialogContext, false),
            onOpen: () => Navigator.pop(dialogContext, true),
          ),
        ) ??
        false;
  }

  String feeDescription(
    BuildContext context,
    SendState state, {
    bool confirmed = false,
  }) {
    final slot = state.feePreviewCache.slotFor(state.selectedFeeOption);
    final fee = state.selectedFee;
    final (feeSat, size) = confirmed
        ? (state.absoluteFees, state.bitcoinTxSize)
        : slot.feeSat != null && slot.txSize != null
        ? (slot.feeSat, slot.txSize)
        : (state.absoluteFees, state.bitcoinTxSize);
    final rate = !confirmed && fee is RelativeFee
        ? fee.satPerVbyte
        : feeSat != null && size != null && size > 0
        ? feeSat / size
        : null;
    final formatted = rate
        ?.toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    return [
      feeTime(context, state.selectedFeeOption),
      if (formatted != null) '$formatted ${context.loc.sendSatsPerVB}',
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  Widget review(BuildContext context, SendState state) {
    final sats = state.isMaxSend && state.recipientAmountsSat.length == 1
        ? state.recipientAmountsSat.single
        : state.confirmedAmountSat ?? state.effectiveAmountSat;
    final fee = state.absoluteFees;
    final entered = state.confirmedConversion;
    final quoteTime = entered?.quotedAt.toLocal();
    return SendPaymentReview(
      title: context.loc.sendTitle,
      stepLabels: steps(context),
      stepSemanticLabel: (i, label) => '${i + 1}: $label',
      youSendLabel: context.loc.sendYouSend,
      amount: money(context, sats, style: context.bullType.headline),
      equivalent: fiat(state, sats),
      enteredDetail: entered == null || quoteTime == null
          ? null
          : context.loc.sendEnteredQuote(
              entered.enteredText,
              entered.currencyCode,
              '${quoteTime.hour.toString().padLeft(2, '0')}:${quoteTime.minute.toString().padLeft(2, '0')}',
            ),
      recipients: state.hasMultipleRecipients
          ? [
              for (var i = 0; i < state.recipientDrafts.length; i++)
                (
                  label: context.loc.sendToRecipientNumber(i + 1),
                  value: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (state.recipientAmountsSat.length > i)
                        money(context, state.recipientAmountsSat[i]),
                      AddressViewer(
                        state.recipientDrafts[i].address,
                        style: context.bullType.label,
                        color: context.bull.textMuted,
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
            ]
          : [
              (
                label: context.loc.sendTo,
                value: AddressViewer(
                  state.paymentRequestAddress,
                  clipboardText: state.copiedRawPaymentRequest,
                  style: context.bullType.body,
                  color: context.bull.text,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
      fromLabel: context.loc.sendFrom,
      source: Text(
        state.selectedWallet?.displayLabel(context) ?? '',
        style: context.bullType.body,
      ),
      editLabel: context.loc.sendEdit,
      noteLabel: context.loc.transactionNoteHint,
      note: state.label,
      feeLabel: context.loc.sendNetworkFees,
      fee: fee == null ? const BullLoader.small() : money(context, fee),
      // Liquid has a single network rate: no preset to name.
      feeDetail: state.selectedWallet?.isLiquid == true
          ? ''
          : [
              feeName(context, state.selectedFeeOption),
              feeDescription(context, state, confirmed: true),
            ].where((part) => part.isNotEmpty).join(' · '),
      totalLabel: context.loc.sendTotal,
      total: fee == null
          ? const BullLoader.small()
          : money(
              context,
              sats + fee,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
      totalEquivalent: fee == null ? null : fiat(state, sats + fee),
      error: state.failure == null ? null : const _SendError(),
      feeWarning:
          state.showFeeWarning || state.isUnconfidentialLiquidDestination
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.isUnconfidentialLiquidDestination)
                  const _UnconfidentialLiquidWarning(),
                if (state.showFeeWarning &&
                    state.isUnconfidentialLiquidDestination)
                  const Gap(BullSpacing.sm),
                if (state.showFeeWarning)
                  _HighFeeWarning(state.getFeeAsPercentOfAmount()),
              ],
            )
          : null,
      confirmLabel: context.loc.sendConfirm,
      onBack: cubit.backClicked,
      onNote: () async {
        final note = await LabelEditor.label(
          context,
          title: context.loc.transactionNoteAddTitle,
          initialValue: state.label.isEmpty ? null : state.label,
          hint: context.loc.transactionNoteHint,
          suggestionsFuture: cubit.fetchDistinctLabels(),
          // The note is optional: saving it empty removes it.
          allowEmpty: true,
        );
        if (!_disposed && note != null) cubit.noteChanged(note);
      },
      onConfirm: fee == null || state.disableConfirmSend ? null : confirm,
    );
  }
}
