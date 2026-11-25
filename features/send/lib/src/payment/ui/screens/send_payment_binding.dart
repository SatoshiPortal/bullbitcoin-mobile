part of 'send_screen.dart';

/// Owns ephemeral mono UI state; transaction intent remains in SendCubit.
final class _SendPaymentSession {
  _SendPaymentSession(this.cubit, this.confirm)
    : amountController = TextEditingController(text: cubit.state.amount),
      unit = ValueNotifier(cubit.state.bitcoinUnit ?? BitcoinUnit.btc);
  final SendCubit cubit;
  final Future<void> Function() confirm;
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
    if (cubit.isSpMode ||
        state.isSweep ||
        state.usesSelectedInputsOnly ||
        state.hasMultipleRecipients ||
        state.hasFixedRequestAmount ||
        state.selectedWallet?.isLiquid == true ||
        state.selectedWallet?.isHardwareWallet == true ||
        state.selectedWallet?.signsLocally == false ||
        state.isPayjoinAvailable) {
      return false;
    }
    final request = state.paymentRequest;
    return request == null ||
        const BitcoinRecipientListPolicy().isPlainAddress(request);
  }

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
              padding: const EdgeInsets.all(BullSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: AddressViewer(
                      state.paymentRequestAddress,
                      clipboardText: state.copiedRawPaymentRequest,
                      style: context.bullType.body,
                    ),
                  ),
                  BullFieldAction(
                    icon: BullIcons.edit,
                    label: context.loc.sendEdit,
                    onPressed: edit,
                  ),
                ],
              ),
            )
          : AddressField(onInput: input, onScanned: scan, showLabel: false),
      amountLabel: context.loc.sendAmount,
      lockedAmountLabel: context.loc.sendAmountLocked,
      amount: ValueListenableBuilder<BitcoinUnit>(
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
          isMax: state.isMaxSend,
          maxLoading: state.isMaxSend && cubit.preparedMaxAmountSat == null,
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
      walletLabel: wallet?.displayLabel(context) ?? '',
      walletColor: switch (state.selectedBitcoinWallet) {
        final wallet? => wallet.tagColor(context),
        null => context.bull.secondary,
      },
      walletActionLabel: context.loc.sendFrom,
      maxLabel: 'MAX',
      settingsLabel: context.loc.sendAdvancedSettings,
      feeSummary: feeName(context, state.selectedFeeOption),
      continueLabel: context.loc.sendContinue,
      recipientReady: ready,
      isBusy: state.loadingBestWallet || state.buildingTransaction,
      onBack: () {
        if (ready) {
          edit();
        } else {
          context.pop();
        }
      },
      onSettings: () => settings(context),
      onMax: ready ? () => max(context) : null,
      onWallet: ready ? () => wallets(context) : null,
      onContinue:
          ready &&
              state.effectiveAmountSat > 0 &&
              state.hasValidAmountEntry &&
              state.failure == null &&
              !state.amountConfirmedClicked &&
              !state.buildingTransaction
          ? () {
              amountFocus.unfocus();
              cubit.onAmountConfirmed();
            }
          : null,
    );
  }

  Future<void> wallets(BuildContext context) async {
    amountFocus.unfocus();
    final wallets = cubit.state.wallets
        .where((wallet) => !wallet.isLiquid && wallet.signerDevice == null)
        .toList();
    final selected = await BullBottomSheet.show<SendSource>(
      context: context,
      child: BullPickerSheet<SendSource>(
        title: context.loc.sendFrom,
        options: wallets,
        isSelected: (wallet) => wallet.id == cubit.state.selectedWallet?.id,
        label: (wallet) => wallet.displayLabel(context),
        subtitle: (wallet) {
          final type = wallet.isWatchOnly || wallet.signsRemotely
              ? wallet.typeLabel(context)
              : context.loc.sendSecureWalletDescription;
          final balance = switch (wallet.balanceSat) {
            final amount? => FormatAmount.sats(amount.toInt()),
            null => context.loc.walletLoadFailed,
          };
          return '$type · $balance';
        },
      ),
    );
    if (!_disposed && selected != null) {
      await cubit.updateSelectedWallet(selected);
    }
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
    final accepted = await BullDialog.show<bool>(
      context: context,
      builder: (dialogContext) => SendWholeBalanceDialog(
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
        balance: money(context, preview.availableSat),
        feeLabel:
            '${context.loc.sendNetworkFees} · ${feeName(context, cubit.state.selectedFeeOption)}',
        fee: money(context, preview.feeSat, negative: true),
        receivesLabel: context.loc.sendRecipientGets,
        receives: money(
          context,
          preview.recipientSat,
          style: context.bullType.subtitle,
        ),
        cancelLabel: context.loc.cancel,
        sendAllLabel: context.loc.sendAllAction,
        onCancel: () => Navigator.pop(dialogContext, false),
        onSendAll: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (!_disposed && accepted == true) {
      final applied = await cubit.acceptMonoMax(preview);
      if (!applied && context.mounted) {
        BullSnackBar.show(context, message: context.loc.sendPaymentChanged);
      }
    }
  }

  Future<void> settings(BuildContext context) async {
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
                onMultipleRecipients: null,
                onCoins: state.selectedBitcoinWallet == null
                    ? null
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
            final effective = evaluation.effectiveRate;
            final help = [
              if (effective != null)
                context.loc.sendCustomEffectiveRate(
                  '${evaluation.effectiveRateIsApproximate ? '≈ ' : ''}$effective',
                ),
              if (evaluation.estimatedSats case final n?)
                '≈ $n ${context.loc.sendSats}',
              if (evaluation.estimatedSats case final n?)
                fiat(state, n.toInt()),
              feeTime(context, state.selectedFeeOption),
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
              applyHint: context.loc.sendCustomApplyHint,
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
      recipients: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${context.loc.sendTo} · ${context.loc.exchangeDcaAddressLabelBitcoin}',
              style: context.bullType.label.copyWith(
                color: context.bull.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Gap(BullSpacing.xs),
            SendGroupedAddress(
              address: state.paymentRequestAddress,
              onOpen: () => AddressViewer.showDetail(
                context,
                data: state.paymentRequestAddress,
                clipboardText: state.copiedRawPaymentRequest,
              ),
              onCopy: () => Clipboard.setData(
                ClipboardData(text: state.paymentRequestAddress),
              ),
            ),
          ],
        ),
      ],
      fromLabel: context.loc.sendFrom,
      source: Text(
        state.selectedWallet?.displayLabel(context) ?? '',
        style: context.bullType.body,
      ),
      editLabel: context.loc.sendEdit,
      noteLabel: context.loc.transactionNoteHint,
      note: state.label.isEmpty
          ? context.loc.transactionNoteAddTitle
          : state.label,
      feeLabel: context.loc.sendNetworkFees,
      fee: fee == null ? const BullLoader.small() : money(context, fee),
      feeDetail: [
        feeName(context, state.selectedFeeOption),
        feeDescription(context, state, confirmed: true),
      ].where((part) => part.isNotEmpty).join(' · '),
      totalLabel: context.loc.sendTotalDebited,
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
      feeWarning: state.showFeeWarning
          ? _HighFeeWarning(state.getFeeAsPercentOfAmount())
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
        );
        if (!_disposed && note != null) cubit.noteChanged(note);
      },
      onConfirm: fee == null || state.disableConfirmSend ? null : confirm,
    );
  }
}
