import 'dart:async';
import 'dart:math' as math;

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/screens/send_confirm_screen.dart' hide SendType;
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';

import 'package:bb_mobile/core/widgets/cards/consolidation_required_card.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/price_input/balance_row.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/presentation/send_failure_l10n.dart';
import 'package:bb_mobile/features/send/ui/screens/open_the_camera_widget.dart';
import 'package:bb_mobile/features/send/ui/screens/send_signing_screen.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/fees/fee_options_modal.dart';
import 'package:bb_mobile/core/widgets/fees/fee_selection_label.dart';
import 'package:bb_mobile/features/send/ui/widgets/advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/features/send/ui/widgets/multi_recipient_transaction_review.dart';
import 'package:bb_mobile/features/send/ui/widgets/recipient_fields.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_info_row.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_selection_bottom_sheet.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_path_tile.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_action_buttons.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_error.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/consolidation/public/consolidation_facade.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBorderedTile,
        BullBottomSheet,
        BullButton,
        BullCountdown,
        BullFadingLinearProgress,
        BullInfoCard,
        BullInputText,
        BullSegmented,
        BullShapesX,
        BullText,
        BullTopBar,
        Gap;
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

String _sendFlowTitle(BuildContext context) {
  final isSweep = context.select((SendCubit cubit) => cubit.state.isSweep);
  return isSweep ? context.loc.coinsSweepTitle : context.loc.sendTitle;
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class SendLoadingScreen extends StatelessWidget {
  final bool hasError;

  const SendLoadingScreen({super.key, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.sendTitle,
          color: context.appColors.background,
          onBack: () => context.pop(),
        ),
      ),
      body: Center(
        child: ProgressScreen(
          isLoading: !hasError,
          title: hasError
              ? context.loc.oopsSomethingWentWrong
              : context.loc.sendLoadingTransaction,
        ),
      ),
    );
  }
}

class _SendScreenState extends State<SendScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (lifecycleState) {
        if (lifecycleState != AppLifecycleState.resumed) {
          unawaited(context.read<SendCubit>().flushDraft());
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = context.select<SendCubit, SendStep>(
      (cubit) => cubit.state.step,
    );
    final screen = BlocListener<SendCubit, SendState>(
      listenWhen: (previous, current) =>
          !previous.keptPreviousDraft && current.keptPreviousDraft,
      listener: (context, state) => SnackBarUtils.showSnackBar(
        context,
        context.loc.sendDraftKeptForLater,
      ),
      child: switch (step) {
        SendStep.address => const SendAddressScreen(),
        SendStep.amount => const SendAmountScreen(),
        SendStep.confirm => const SendConfirmScreen(),
        SendStep.signing => const SendSigningScreen(),
        SendStep.sending => const SendSendingScreen(),
        SendStep.success => const SendSucessScreen(),
      },
    );
    if (step != SendStep.address &&
        step != SendStep.amount &&
        step != SendStep.confirm) {
      return screen;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleEditableSendBack(context);
      },
      child: screen,
    );
  }
}

class SendAddressScreen extends StatelessWidget {
  const SendAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final addressState = context.select(
      (SendCubit cubit) => (
        recipients: cubit.state.recipientDrafts,
        canAddRecipient: !cubit.isSpMode && cubit.state.canAddRecipient,
      ),
    );
    final cubit = context.read<SendCubit>();
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: _sendFlowTitle(context),
          color: context.appColors.background,
          onBack: () => _handleEditableSendBack(context),
          action: const SendDraftAppBarAction(),
        ),
      ),
      body: Stack(
        fit: .expand,
        children: [
          Column(
            children: [
              BullFadingLinearProgress(
                height: 3,
                trigger: context.select(
                  (SendCubit cubit) =>
                      cubit.state.loadingBestWallet || cubit.state.creatingSwap,
                ),
                backgroundColor: context.appColors.onSecondary,
                foregroundColor: context.appColors.primary,
              ),
              Expanded(
                child: Stack(
                  fit: .expand,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: OpenTheCameraWidget(
                        disabled: context.select(
                          (SendCubit cubit) =>
                              cubit.state.selectedInputsUnavailable,
                        ),
                        onScannedPaymentRequest: (data) => context
                            .read<SendCubit>()
                            .onScannedPaymentRequest(data.$1, data.$2),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.appColors.onSecondary,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                context.bullShapes.sheet,
                              ),
                              topRight: Radius.circular(
                                context.bullShapes.sheet,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: .stretch,
                            mainAxisSize: .min,
                            children: [
                              const Gap(32),
                              RecipientAddressFields(
                                recipients: addressState.recipients,
                                primaryField: const AddressField(),
                                onRemoveRecipient: cubit.removeRecipient,
                                onAddressChanged: cubit.recipientAddressChanged,
                              ),
                              AddRecipientButton(
                                canAdd: addressState.canAddRecipient,
                                onAdd: () async {
                                  await cubit.addRecipient();
                                },
                              ),
                              const AddressErrorSection(),
                              const Gap(16),
                              const SendContinueWithAddressButton(),
                              const Gap(42),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SendContinueWithAddressButton extends StatelessWidget {
  const SendContinueWithAddressButton({super.key});

  @override
  Widget build(BuildContext context) {
    final loadingBestWallet = context.select(
      (SendCubit cubit) => cubit.state.loadingBestWallet,
    );
    final hasRecipientInput = context.select(
      (SendCubit cubit) =>
          cubit.state.copiedRawPaymentRequest.trim().isNotEmpty,
    );
    final creatingSwap = context.select(
      (SendCubit cubit) => cubit.state.creatingSwap,
    );
    final selectedInputsUnavailable = context.select(
      (SendCubit cubit) => cubit.state.selectedInputsUnavailable,
    );
    final hasInvalidAdditionalRecipient = context.select(
      (SendCubit cubit) => cubit.state.hasInvalidAdditionalRecipient,
    );

    return BullButton.big(
      label: context.loc.sendContinue,
      onPressed: () {
        context.read<SendCubit>().continueOnAddressConfirmed();
      },
      disabled:
          !hasRecipientInput ||
          hasInvalidAdditionalRecipient ||
          loadingBestWallet ||
          creatingSwap ||
          selectedInputsUnavailable,
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
    );
  }
}

class AddressField extends StatelessWidget {
  const AddressField({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.select<SendCubit, String>(
      (cubit) => cubit.state.copiedRawPaymentRequest,
    );
    final selectedInputsUnavailable = context.select(
      (SendCubit cubit) => cubit.state.selectedInputsUnavailable,
    );
    final restricted = context.read<SendCubit>().isRestrictedSend;

    return BullInputText(
      onChanged: context.read<SendCubit>().onChangedText,
      value: address,
      disabled: restricted || selectedInputsUnavailable,
      hint: context.loc.sendPasteAddressOrInvoice,
      hintStyle: context.font.bodyLarge?.copyWith(
        color: context.appColors.textMuted,
      ),
      maxLines: 1,
      rightIcon: restricted
          ? null
          : Icon(
              Icons.paste_sharp,
              color: context.appColors.secondary,
              size: 20,
            ),
      onRightTap: restricted
          ? null
          : () {
              Clipboard.getData(Clipboard.kTextPlain).then((value) {
                if (value != null) {
                  if (context.mounted) {
                    context.read<SendCubit>().onChangedText(value.text ?? '');
                  }
                }
              });
            },
    );
  }
}

class AddressErrorSection extends StatelessWidget {
  const AddressErrorSection({super.key});

  @override
  Widget build(BuildContext context) {
    final failure = context.select((SendCubit cubit) => cubit.state.failure);
    final frozenBalanceHint = context.select(
      (SendCubit cubit) => cubit.state.frozenBalanceHint,
    );
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: BullText(
          failure.toTranslated(
            context,
            formattedFrozenBalance: frozenBalanceHint,
          ),
          style: context.font.bodyMedium,
          color: context.appColors.error,
          textAlign: .center,
          maxLines: 2,
        ),
      );
    }
    return const SizedBox(height: 21);
  }
}

class SendAmountScreen extends StatefulWidget {
  const SendAmountScreen({super.key});

  @override
  State<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends State<SendAmountScreen> {
  late TextEditingController _amountController;
  late FocusNode _amountFocusNode;
  final Map<int, FocusNode> _recipientAmountFocusNodes = {};

  @override
  void initState() {
    super.initState();
    final amount = context.read<SendCubit>().state.amount;
    _amountController = TextEditingController.fromValue(
      TextEditingValue(
        text: amount,
        selection: TextSelection.collapsed(offset: amount.length),
      ),
    );
    _amountFocusNode = FocusNode();
    _amountController.addListener(() {
      final text = _amountController.text;
      final cubit = context.read<SendCubit>();
      if (text != cubit.state.amount && !cubit.state.isMaxSend) {
        cubit.amountChanged(amount: text);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    for (final focusNode in _recipientAmountFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipientDrafts = context.select(
      (SendCubit cubit) => cubit.state.recipientDrafts,
    );
    for (final recipient in recipientDrafts) {
      _recipientAmountFocusNodes.putIfAbsent(recipient.id, FocusNode.new);
    }
    return Scaffold(
      backgroundColor: context.appColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: _sendFlowTitle(context),
          onBack: () => _handleEditableSendBack(context),
          action: const SendDraftAppBarAction(),
        ),
      ),
      body: Column(
        children: [
          BullFadingLinearProgress(
            height: 3,
            trigger: context.select(
              (SendCubit cubit) => cubit.state.creatingSwap,
            ),
            backgroundColor: context.appColors.background,
            foregroundColor: context.appColors.primary,
          ),
          Expanded(
            child: BBKeyboardActions(
              disableScroll: true,
              focusNodes: [
                _amountFocusNode,
                for (final recipient in recipientDrafts)
                  ?_recipientAmountFocusNodes[recipient.id],
              ],
              child: BlocListener<SendCubit, SendState>(
                listenWhen: (previous, current) =>
                    previous.amount != current.amount &&
                    _amountController.text != current.amount,
                listener: (context, state) {
                  final amount = state.amount;
                  final currentCursor = _amountController.selection.baseOffset;
                  final safePosition = state.isMaxSend
                      ? amount.length
                      : math.min(currentCursor, amount.length);

                  _amountController.value = TextEditingValue(
                    text: amount,
                    selection: TextSelection.collapsed(offset: safePosition),
                  );
                },
                child: BlocBuilder<SendCubit, SendState>(
                  builder: (context, state) {
                    final failure = context.select(
                      (SendCubit cubit) => cubit.state.failure,
                    );
                    final balanceError = context.select(
                      (SendCubit cubit) => cubit.state.hasBalanceFailure,
                    );
                    final frozenBalanceHint = context.select(
                      (SendCubit cubit) => cubit.state.frozenBalanceHint,
                    );
                    final suggestsInstantPayments = context.select(
                      (SendCubit cubit) => cubit.state.suggestsInstantPayments,
                    );
                    final walletHasBalance = context.select(
                      (SendCubit cubit) => cubit.state.walletHasBalance,
                    );
                    final amountConfirmedClicked = context.select(
                      (SendCubit cubit) => cubit.state.amountConfirmedClicked,
                    );
                    final isLightning = context.select(
                      (SendCubit cubit) => cubit.state.isLightning,
                    );
                    final isChainSwap = context.select(
                      (SendCubit cubit) => cubit.state.chainSwap != null,
                    );
                    final inputCurrency = context.select(
                      (SendCubit cubit) => cubit.state.inputAmountCurrencyCode,
                    );

                    final availableInputCurrencies = context
                        .select<SendCubit, List<String>>(
                          (bloc) => bloc.state.inputAmountCurrencyCodes,
                        );
                    final buildError = context.select(
                      (SendCubit cubit) => cubit.state.hasBuildFailure,
                    );
                    final selectedWallet = context.select(
                      (SendCubit cubit) => cubit.state.selectedWallet!,
                    );
                    // Only a real wallet can be swapped for another one. Silent
                    // payments has exactly one and nothing to pick from.
                    final pickableWallet = context.select(
                      (SendCubit cubit) => cubit.state.selectedBitcoinWallet,
                    );
                    final wallets = context.select(
                      (SendCubit cubit) => cubit.state.selectableWallets,
                    );
                    return IgnorePointer(
                      ignoring: state.amountConfirmedClicked,
                      child: Column(
                        crossAxisAlignment: .stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: .stretch,
                                children: [
                                  ColoredBox(
                                    color: context.appColors.onSecondary,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                      ),
                                      child:
                                          state.usesSelectedInputsOnly ||
                                              pickableWallet == null
                                          ? SizedBox(
                                              height: 48,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  selectedWallet.displayLabel(
                                                    context,
                                                  ),
                                                  style: context
                                                      .font
                                                      .headlineSmall,
                                                ),
                                              ),
                                            )
                                          : DropdownButtonFormField<String>(
                                              alignment: Alignment.centerLeft,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              icon: Icon(
                                                Icons.keyboard_arrow_down,
                                                color:
                                                    context.appColors.secondary,
                                              ),
                                              iconSize: 24,
                                              initialValue: selectedWallet.id,
                                              items: wallets.map((w) {
                                                return DropdownMenuItem(
                                                  value: w.id,
                                                  child: Text(
                                                    w.displayLabel(context),
                                                    style: context
                                                        .font
                                                        .headlineSmall,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged:
                                                  context
                                                      .read<SendCubit>()
                                                      .isRestrictedSend
                                                  ? null
                                                  : (walletId) {
                                                      if (walletId != null) {
                                                        context
                                                            .read<SendCubit>()
                                                            .updateSelectedWallet(
                                                              wallets.firstWhere(
                                                                (wallet) =>
                                                                    wallet.id ==
                                                                    walletId,
                                                              ),
                                                            );
                                                      }
                                                    },
                                            ),
                                    ),
                                  ),
                                  const Gap(10),
                                  if (state.showsRecipientAmountList)
                                    RecipientAmounts(
                                      recipients: state.recipientDrafts,
                                      preparedAmounts:
                                          state.recipientAmountsSat,
                                      isSweep: state.isSweep,
                                      inputCurrency: inputCurrency,
                                      focusNodes: _recipientAmountFocusNodes,
                                      error: balanceError
                                          ? (state.frozenBalanceSat > 0
                                                ? context.loc
                                                      .sendErrorInsufficientBalanceFrozenHint(
                                                        state
                                                            .formattedFrozenBalance,
                                                      )
                                                : context
                                                      .loc
                                                      .sendErrorInsufficientBalanceForPayment)
                                          : (!walletHasBalance &&
                                                amountConfirmedClicked)
                                          ? context.loc.sendInsufficientBalance
                                          : failure?.toTranslated(context),
                                      onRemoveRecipient: context
                                          .read<SendCubit>()
                                          .removeRecipient,
                                      onAmountChanged: context
                                          .read<SendCubit>()
                                          .recipientAmountChanged,
                                      onRemainderChanged: context
                                          .read<SendCubit>()
                                          .setRemainderRecipient,
                                      amountBuilder: (amountSat) =>
                                          CurrencyText(
                                            amountSat,
                                            showFiat: false,
                                            style: context.font.bodyMedium,
                                            color: context.appColors.textMuted,
                                          ),
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        PriceInput(
                                          currency: inputCurrency,
                                          amountEquivalent: state
                                              .formattedAmountInputEquivalent,
                                          availableCurrencies:
                                              availableInputCurrencies,
                                          amountController: _amountController,
                                          onCurrencyChanged: (currencyCode) {
                                            context
                                                .read<SendCubit>()
                                                .onCurrencyChanged(
                                                  currencyCode,
                                                );
                                          },
                                          error: balanceError && failure != null
                                              ? failure.toTranslated(
                                                  context,
                                                  formattedFrozenBalance:
                                                      frozenBalanceHint,
                                                )
                                              : (!walletHasBalance &&
                                                    amountConfirmedClicked)
                                              ? context
                                                    .loc
                                                    .sendInsufficientBalance
                                              : failure?.toTranslated(context),
                                          focusNode: _amountFocusNode,
                                          readOnly: state.isMaxSend,
                                          isMax: state.isMaxSend,
                                        ),
                                      ],
                                    ),
                                  if (state
                                      .unavailableSelectedOutpoints
                                      .isNotEmpty)
                                    TextButton(
                                      onPressed: () =>
                                          BlurredBottomSheet.show<void>(
                                            context: context,
                                            child: BlocProvider.value(
                                              value: context.read<SendCubit>(),
                                              child:
                                                  const CoinSelectionBottomSheet(),
                                            ),
                                          ),
                                      child: Text(
                                        context.loc.sendSelectCoinsManually,
                                      ),
                                    ),
                                  if (suggestsInstantPayments)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: BullText(
                                        context
                                            .loc
                                            .sendErrorAmountBelowSwapLimitsBitcoin,
                                        style: context.font.bodySmall,
                                        color: context.appColors.error,
                                        maxLines: 3,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  Gap(Device.screen.height * 0.02),
                                  BullBorderedTile(
                                    onTap: () async {
                                      final cubit = context.read<SendCubit>();
                                      final saved =
                                          await LabelEntryBottomSheet.label(
                                            context,
                                            title: context
                                                .loc
                                                .transactionNoteAddTitle,
                                            initialValue: state.label.isEmpty
                                                ? null
                                                : state.label,
                                            hint:
                                                context.loc.transactionNoteHint,
                                            suggestionsFuture: cubit
                                                .fetchDistinctLabels(),
                                          );
                                      if (saved == null || !context.mounted) {
                                        return;
                                      }
                                      cubit.noteChanged(saved);
                                    },
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              BullText(
                                                '${context.loc.receiveNote} (optional)',
                                                style: context.font.bodyLarge,
                                                color:
                                                    context.appColors.secondary,
                                              ),
                                              const Gap(4),
                                              BullText(
                                                state.label.isEmpty
                                                    ? context
                                                          .loc
                                                          .receiveEnterHere
                                                    : state.label,
                                                style: context.font.bodyMedium,
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.edit,
                                          size: 20,
                                          color: context.appColors.secondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Gap(48),
                                  Divider(
                                    height: 1,
                                    color: context.appColors.secondaryFixedDim,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: BalanceRow(
                                      title: state.usesSelectedInputsOnly
                                          ? context.loc.sendSelectedCoinsLabel
                                          : context.loc.addressViewBalance,
                                      balance: state.formattedWalletBalance(),
                                      currencyCode: '',
                                      isMax: state.isMaxSend,
                                      onMaxToggled:
                                          !isLightning &&
                                              !isChainSwap &&
                                              !state.hasMultipleRecipients
                                          ? (value) {
                                              context
                                                  .read<SendCubit>()
                                                  .amountChanged(
                                                    amount: value
                                                        ? null
                                                        : _amountController
                                                              .text,
                                                    isMax: value,
                                                  );
                                              if (!value) {
                                                _amountFocusNode.requestFocus();
                                              }
                                            }
                                          : null,
                                      walletLabel: selectedWallet.label,
                                    ),
                                  ),
                                  if (state.consolidationRequired) ...[
                                    const Gap(16),
                                    ConsolidationRequiredCard(
                                      title: context
                                          .loc
                                          .consolidationRequiredTitle,
                                      onTap: () => context.pushNamed(
                                        ConsolidationRoute.consolidation.name,
                                        pathParameters: {
                                          'walletId': selectedWallet.id,
                                        },
                                      ),
                                    ),
                                  ],
                                  if (buildError) ...[
                                    const Gap(16),
                                    const SendError(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              math.max(16, Device.screen.height * 0.04),
                            ),
                            child: SendAmountConfirmButton(
                              amountController: _amountController,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SendAmountConfirmButton extends StatelessWidget {
  const SendAmountConfirmButton({super.key, required this.amountController});

  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    final amountConfirmedClicked = context.select(
      (SendCubit cubit) => cubit.state.amountConfirmedClicked,
    );
    final creatingSwap = context.select(
      (SendCubit cubit) => cubit.state.creatingSwap,
    );
    final loadingBestWallet = context.select(
      (SendCubit cubit) => cubit.state.loadingBestWallet,
    );
    final inputAmountSat = context.select(
      (SendCubit cubit) => cubit.state.inputAmountSat,
    );
    final recipientAmountsValid = context.select(
      (SendCubit cubit) =>
          !cubit.state.usesRecipientList || cubit.state.hasValidRecipientDrafts,
    );
    final usesRecipientList = context.select(
      (SendCubit cubit) => cubit.state.usesRecipientList,
    );
    return BullButton.big(
      label: context.loc.sendContinue,
      onPressed: () {
        final cubit = context.read<SendCubit>();
        final currentAmount = amountController.text;
        if (!cubit.state.usesRecipientList &&
            currentAmount != cubit.state.amount) {
          cubit.amountChanged(amount: currentAmount);
        }
        cubit.onAmountConfirmed();
      },
      disabled:
          amountConfirmedClicked ||
          creatingSwap ||
          loadingBestWallet ||
          !recipientAmountsValid ||
          (!usesRecipientList && inputAmountSat <= 0),
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onSecondary,
    );
  }
}

class NetworkDisplay extends StatelessWidget {
  const NetworkDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final sendType = context.select<SendCubit, SendType>(
      (cubit) => cubit.state.sendType,
    );

    return AnimatedOpacity(
      opacity: 0.5,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        child: BullSegmented(
          items: SendType.values.map((e) => e.displayName).toSet(),
          onSelected: (c) {},
          initialValue: sendType.displayName,
        ),
      ),
    );
  }
}

class SendConfirmScreen extends StatelessWidget {
  const SendConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningOrder,
    );
    final isLnSwap =
        orderSwap != null &&
        (orderSwap.inNetwork == OrderSwapNetwork.lightning ||
            orderSwap.outNetwork == OrderSwapNetwork.lightning);
    final isChainSwap =
        context.select((SendCubit cubit) => cubit.state.chainSwap != null) ||
        (orderSwap != null && !isLnSwap);
    final isLiquid = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.isLiquid ?? false,
    );
    final isUnconfidentialLiquidDestination = context.select(
      (SendCubit cubit) => cubit.state.isUnconfidentialLiquidDestination,
    );
    final isPreparingTransaction = context.select(
      (SendCubit cubit) =>
          cubit.state.buildingTransaction || cubit.state.signingTransaction,
    );
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: _sendFlowTitle(context),
          onBack: () => _handleEditableSendBack(context),
          backEnabled: !isPreparingTransaction,
          action: const SendDraftAppBarAction(),
        ),
      ),
      body: Column(
        children: [
          BullFadingLinearProgress(
            height: 3,
            trigger: context.select(
              (SendCubit cubit) =>
                  cubit.state.buildingTransaction ||
                  cubit.state.signingTransaction,
            ),
            backgroundColor: context.appColors.background,
            foregroundColor: context.appColors.primary,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    // const Gap(24),
                    const SendConfirmTopArea(),
                    const Gap(40),
                    if (isLnSwap)
                      const _LnSwapSendInfoSection()
                    else if (isChainSwap)
                      const _ChainSwapSendInfoSection()
                    else if (isLiquid)
                      const _LiquidOnchainSendInfoSection()
                    else
                      const _OnchainTransactionReview(),
                    if (isUnconfidentialLiquidDestination) ...[
                      const Gap(16),
                      const _UnconfidentialLiquidWarning(),
                    ],
                    const Gap(40),
                    const SendError(),
                    const _BottomButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SendDraftAppBarAction extends StatelessWidget {
  const SendDraftAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final supportsDraft = state.supportsBitcoinDraft;
    final hasRecipientInput = state.copiedRawPaymentRequest.trim().isNotEmpty;
    if (!supportsDraft || (!state.isDraftSaved && !hasRecipientInput)) {
      return const SizedBox.shrink();
    }
    if (state.persistingPendingTransaction) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (state.isDraftSaved) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: BullText(
            context.loc.sendDraftSaved,
            style: context.font.bodyMedium,
            color: context.appColors.textMuted,
          ),
        ),
      );
    }
    return TextButton(
      onPressed: () => _saveDraftAndLeave(context),
      child: BullText(
        context.loc.save,
        style: context.font.bodyMedium,
        color: context.appColors.secondary,
      ),
    );
  }
}

Future<void> _saveDraftAndLeave(BuildContext context) async {
  final cubit = context.read<SendCubit>();
  final label = await LabelEntryBottomSheet.label(
    context,
    title: context.loc.sendDraftLabelTitle,
    initialValue: cubit.state.label.isEmpty ? null : cubit.state.label,
    hint: context.loc.sendDraftLabelHint,
    allowEmpty: true,
  );
  if (label == null || !context.mounted) return;
  cubit.noteChanged(label);
  if (await cubit.saveDraft() && context.mounted) context.pop();
}

Future<void> _handleEditableSendBack(BuildContext context) async {
  final cubit = context.read<SendCubit>();
  final state = cubit.state;
  if (state.signingTransaction) return;
  if (state.isDraftSaved) {
    if (state.step != SendStep.address) {
      cubit.backClicked();
      return;
    }
    if (await cubit.flushDraft() && context.mounted) context.pop();
    return;
  }
  if (state.step != SendStep.address) {
    cubit.backClicked();
    return;
  }
  if (!state.hasUnsavedDraftChanges) {
    context.pop();
    return;
  }
  final action = await showDialog<_DraftBackAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.loc.sendDraftBackTitle),
      content: Text(context.loc.sendDraftBackMessage),
      actions: [
        TextButton(
          onPressed: () => dialogContext.pop(_DraftBackAction.continueEditing),
          child: Text(context.loc.sendContinueEditing),
        ),
        TextButton(
          onPressed: () => dialogContext.pop(_DraftBackAction.discard),
          child: Text(context.loc.sendDraftDiscard),
        ),
        if (state.supportsBitcoinDraft &&
            state.copiedRawPaymentRequest.trim().isNotEmpty)
          TextButton(
            onPressed: () => dialogContext.pop(_DraftBackAction.save),
            child: Text(context.loc.save),
          ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case _DraftBackAction.save:
      await _saveDraftAndLeave(context);
    case _DraftBackAction.discard:
      context.pop();
    case _DraftBackAction.continueEditing || null:
      break;
  }
}

enum _DraftBackAction { save, discard, continueEditing }

// ignore: unused_element
class _HighFeeWarning extends StatelessWidget {
  final double feePercent;
  const _HighFeeWarning(this.feePercent);

  @override
  Widget build(BuildContext context) {
    return BullInfoCard(
      title: context.loc.sendHighFeeWarning,
      description: context.loc.sendHighFeeWarningDescription(
        feePercent.toStringAsFixed(2),
      ),
      tagColor: context.appColors.error,
      bgColor: context.appColors.errorContainer,
    );
  }
}

class _SlowPaymentWarning extends StatelessWidget {
  const _SlowPaymentWarning();

  @override
  Widget build(BuildContext context) {
    return BullInfoCard(
      title: context.loc.sendSlowPaymentWarning,
      description: context.loc.sendSlowPaymentWarningDescription,
      tagColor: context.appColors.error,
      bgColor: context.appColors.errorContainer,
    );
  }
}

class _BottomButtons extends StatelessWidget {
  const _BottomButtons();

  @override
  Widget build(BuildContext context) {
    final isBitcoinWallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.isLiquid == false,
    );
    final isOnchainSend = context.select(
      (SendCubit cubit) => !cubit.state.isLightning && !cubit.state.isChainSwap,
    );
    final isSweep = context.select((SendCubit cubit) => cubit.state.isSweep);
    final wallet = context.select(
      (SendCubit cubit) => cubit.state.selectedBitcoinWallet,
    );
    final hasFinalizedTx = context.select(
      (SendCubit cubit) => cubit.state.hasFinalizedBitcoinTransaction,
    );
    final requiresExternalSigning = context.select(
      (SendCubit cubit) => cubit.state.requiresExternalBitcoinSigning,
    );
    final isSpMode = context.read<SendCubit>().isSpMode;
    final transactionBusy = context.select(
      (SendCubit cubit) =>
          cubit.state.buildingTransaction ||
          cubit.state.signingTransaction ||
          cubit.state.broadcastingTransaction,
    );
    final needsCoordination = context.select(
      (SendCubit cubit) => cubit.state.requiresBitcoinSigningCoordination,
    );
    final singleSigner = context.select((SendCubit cubit) {
      final signers = cubit.state.eligibleBitcoinSigners;
      return signers.length == 1 ? signers.single : null;
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if ((isBitcoinWallet || (isOnchainSend && !isSweep)) &&
              !hasFinalizedTx &&
              !isSpMode) ...[
            BullButton.big(
              label: context.loc.sendAdvancedSettings,
              disabled: transactionBusy,
              onPressed: () {
                BullBottomSheet.show(
                  context: context,
                  child: BlocProvider.value(
                    value: context.read<SendCubit>(),
                    child: const AdvancedOptionsBottomSheet(),
                  ),
                );
              },
              borderColor: context.appColors.secondary,
              outlined: true,
              bgColor: context.appColors.transparent,
              textColor: context.appColors.secondary,
            ),
            const Gap(12),
          ],
          if (wallet != null && needsCoordination && !hasFinalizedTx)
            BullButton.big(
              label: context.loc.sendContinueToSigning,
              onPressed: () =>
                  context.read<SendCubit>().continueToBitcoinSigning(),
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
              disabled: context.select(
                (SendCubit cubit) => cubit.state.disableConfirmSend,
              ),
            )
          else if (wallet != null && requiresExternalSigning && !hasFinalizedTx)
            (wallet.signers.length == 1 &&
                    wallet.scriptType != null &&
                    singleSigner?.signerDevice?.isLedger == true)
                ? SignLedgerButton(signer: singleSigner)
                : (wallet.signers.length == 1 &&
                      wallet.scriptType != null &&
                      singleSigner?.signerDevice?.isBitBox == true)
                ? SignBitBoxButton(signer: singleSigner)
                : ShowPsbtButton(signer: singleSigner)
          else
            const ConfirmSendButton(),
        ],
      ),
    );
  }
}

/// Bitcoin onchain send info section.
///
/// Reads directly from [SendState] — all data (amount, address, fees) is
/// already available after [createTransaction] + [signTransaction].
/// Uses [CommonOnchainSendInfoSection] for the layout, same as Liquid.
class _OnchainTransactionReview extends StatelessWidget {
  const _OnchainTransactionReview();

  @override
  Widget build(BuildContext context) {
    final hasMultipleRecipients = context.select(
      (SendCubit cubit) => cubit.state.hasMultipleRecipients,
    );
    if (hasMultipleRecipients) {
      final state = context.watch<SendCubit>().state;
      return MultiRecipientTransactionReview(
        walletLabel: state.selectedWallet?.displayLabel(context) ?? '',
        recipients: state.recipientDrafts,
        recipientAmountsSat: state.recipientAmountsSat,
        label: state.label,
        formattedAbsoluteFees: state.formattedAbsoluteFees,
        feePriorityTitle: state.selectedFeeOption.title(),
        amountBuilder: (amountSat) => CurrencyText(
          amountSat,
          showFiat: false,
          style: context.font.bodyLarge,
          color: context.appColors.secondary,
        ),
        onFeePriorityTap: state.signedBitcoinTx == null
            ? () => _showBitcoinFeeOptions(context)
            : null,
        selectedCoinsDetails: state.selectedUtxos.isEmpty
            ? null
            : _SelectedCoinsDetails(
                count: state.selectedUtxos.length,
                totalSat: state.selectedSpendableBalanceSat,
              ),
        feeWarning: state.showFeeWarning
            ? _HighFeeWarning(state.getFeeAsPercentOfAmount())
            : null,
      );
    }
    final selectedWallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final paymentRequestAddress = context.select(
      (SendCubit cubit) => cubit.state.paymentRequestAddress,
    );
    final formattedBitcoinAmount = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );
    final formattedFiatEquivalent = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountFiat,
    );
    final formattedAbsoluteFees = context.select(
      (SendCubit cubit) => cubit.state.formattedAbsoluteFees,
    );
    final hasFinalizedTx = context.select(
      (SendCubit cubit) => cubit.state.hasFinalizedBitcoinTransaction,
    );
    final selectedFeeOption = context.select(
      (SendCubit cubit) => cubit.state.selectedFeeOption,
    );
    final customFee = context.select(
      (SendCubit cubit) => cubit.state.customFee,
    );
    final feePercent = context.select(
      (SendCubit cubit) => cubit.state.getFeeAsPercentOfAmount(),
    );
    final showFeeWarning = context.select(
      (SendCubit cubit) => cubit.state.showFeeWarning,
    );
    final isToSelf = context.select(
      (SendCubit cubit) => cubit.state.isToSelf == true,
    );
    final label = context.select((SendCubit cubit) => cubit.state.label);
    final isPayjoinAvailable = context.select(
      (SendCubit cubit) => cubit.state.isPayjoinAvailable,
    );
    final willAttemptPayjoin = context.select(
      (SendCubit cubit) => cubit.state.willAttemptPayjoin,
    );
    final isSpMode = context.read<SendCubit>().isSpMode;
    final selectedCoins = context.select(
      (SendCubit cubit) => (
        count: cubit.state.selectedUtxos.length,
        totalSat: cubit.state.selectedSpendableBalanceSat,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BitcoinPolicyPathTile(),
        if (context.select((SendCubit cubit) {
          final policy = cubit.state.bitcoinSigningPlan?.policy;
          return policy?.requiresPath == true ||
              policy?.hasTimelock == true ||
              policy?.hasHashlock == true;
        }))
          const Gap(16),
        CommonOnchainSendInfoSection(
          sendWalletLabel: selectedWallet?.displayLabel(context) ?? '',
          receiveWalletLabel: paymentRequestAddress,
          formattedBitcoinAmount: formattedBitcoinAmount,
          formattedFiatEquivalent: formattedFiatEquivalent.isEmpty
              ? ''
              : '~$formattedFiatEquivalent',
          absoluteFees: formattedAbsoluteFees,
          selectedFeeOptionTitle: feeSelectionRowLabel(
            context,
            selection: selectedFeeOption,
            customFee: customFee,
            fastestLabel: context.loc.sendFastFee,
          ),
          isToSelf: isToSelf,
          payjoinToggleValue: isPayjoinAvailable ? willAttemptPayjoin : null,
          onPayjoinToggleChanged: (attempt) =>
              context.read<SendCubit>().togglePayjoin(attempt),
          note: label,
          onFeePriorityTap: hasFinalizedTx || isSpMode
              ? null
              : () => _showBitcoinFeeOptions(context),
        ),
        if (selectedCoins.count > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SendInfoRow(
              title: context.loc.sendCoinControl,
              details: _SelectedCoinsDetails(
                count: selectedCoins.count,
                totalSat: selectedCoins.totalSat,
              ),
            ),
          ),
        if (showFeeWarning == true) ...[
          const Gap(16),
          _HighFeeWarning(feePercent),
        ],
      ],
    );
  }
}

class _SelectedCoinsDetails extends StatelessWidget {
  const _SelectedCoinsDetails({required this.count, required this.totalSat});

  final int count;
  final int totalSat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        BullText(
          context.loc.coinsSelectedCount(count),
          style: context.font.bodyLarge,
          color: context.appColors.secondary,
          textAlign: TextAlign.end,
        ),
        CurrencyText(
          totalSat,
          showFiat: false,
          style: context.font.labelSmall,
          color: context.appColors.secondary,
        ),
      ],
    );
  }
}

Future<void> _showBitcoinFeeOptions(BuildContext context) async {
  final sendCubit = context.read<SendCubit>();
  final selected = await BullBottomSheet.show<String>(
    context: context,
    child: FeeOptionsModal(
      viewState: sendCubit,
      actions: sendCubit,
      defaultAbsoluteCustomFee: false,
      customFeeColors: FeeModalCustomFeeColors(
        tile: context.appColors.surface,
        shadow: context.appColors.border,
        unselectedIcon: context.appColors.textMuted,
      ),
    ),
  );
  if (selected != null) {
    await sendCubit.feeOptionSelected(FeeSelectionName.fromString(selected));
  } else {
    await sendCubit.finalizeArmedCustomFee();
  }
}

/// Liquid onchain send info section.
///
/// For Liquid wallets, `walletTransaction` is not populated during the confirm
/// step (only `unsignedPsbt` and `liquidAbsoluteFees` are set). Instead of
/// using [TransactionReviewView] (which requires a [ReviewableTransaction]), this
/// widget reads directly from [SendState] and delegates to
/// [CommonOnchainSendInfoSection].
class _LiquidOnchainSendInfoSection extends StatelessWidget {
  const _LiquidOnchainSendInfoSection();

  @override
  Widget build(BuildContext context) {
    final selectedWallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final paymentRequestAddress = context.select(
      (SendCubit cubit) => cubit.state.paymentRequestAddress,
    );
    final formattedBitcoinAmount = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );
    final formattedFiatEquivalent = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountFiat,
    );
    final formattedAbsoluteFees = context.select(
      (SendCubit cubit) => cubit.state.formattedAbsoluteFees,
    );
    final selectedCoins = context.select(
      (SendCubit cubit) => (
        count: cubit.state.selectedUtxos.length,
        totalSat: cubit.state.selectedSpendableBalanceSat,
      ),
    );

    final label = context.select((SendCubit cubit) => cubit.state.label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommonOnchainSendInfoSection(
          sendWalletLabel: selectedWallet?.displayLabel(context) ?? '',
          receiveWalletLabel: paymentRequestAddress,
          formattedBitcoinAmount: formattedBitcoinAmount,
          formattedFiatEquivalent: formattedFiatEquivalent.isEmpty
              ? ''
              : '~$formattedFiatEquivalent',
          absoluteFees: formattedAbsoluteFees,
          selectedFeeOptionTitle: '',
          note: label,
          // Liquid has fixed fees — no fee priority selector
          onFeePriorityTap: null,
        ),
        if (selectedCoins.count > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SendInfoRow(
              title: context.loc.sendCoinControl,
              details: _SelectedCoinsDetails(
                count: selectedCoins.count,
                totalSat: selectedCoins.totalSat,
              ),
            ),
          ),
      ],
    );
  }
}

/// Warns that the destination Liquid address is unconfidential: the amount
/// sent to it will be publicly visible on-chain.
class _UnconfidentialLiquidWarning extends StatelessWidget {
  const _UnconfidentialLiquidWarning();

  @override
  Widget build(BuildContext context) {
    return BullInfoCard(
      title: context.loc.sendUnconfidentialLiquidWarning,
      description: context.loc.sendUnconfidentialLiquidWarningDescription,
      tagColor: context.appColors.error,
      bgColor: context.appColors.errorContainer,
    );
  }
}

class _LnSwapSendInfoSection extends StatelessWidget {
  const _LnSwapSendInfoSection();
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final paymentRequestAddress = context.select(
      (SendCubit cubit) => cubit.state.paymentRequestAddress,
    );
    final swap = context.select(
      (SendCubit cubit) => cubit.state.lightningOrder,
    );
    final feePercent = context.select(
      (SendCubit cubit) => cubit.state.getFeeAsPercentOfAmount(),
    );
    final showFeeWarning = context.select(
      (SendCubit cubit) => cubit.state.showFeeWarning,
    );
    final isSlowPayment = context.select(
      (SendCubit cubit) => cubit.state.isSlowPayment,
    );
    final label = context.select((SendCubit cubit) => cubit.state.label);
    final networkFee = context.select(
      (SendCubit cubit) => cubit.state.absoluteFees,
    );
    final swapFee = context.select(
      (SendCubit cubit) => cubit.state.totalSwapFees,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          SendInfoRow(
            title: context.loc.sendFrom,
            details: BullText(
              selectedWallet!.displayLabel(context),
              style: context.font.bodyLarge,
              color: context.appColors.secondary,
              textAlign: .end,
            ),
          ),
          _divider(context),
          SendInfoRow(
            title: context.loc.sendSwapId,
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: BullText(
                    swap!.order!.orderNumber.toString(),
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                    textAlign: .end,
                  ),
                ),
                const Gap(4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: swap.order!.orderNumber.toString()),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    color: context.appColors.primary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          SendInfoRow(
            title: context.loc.sendTo,
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: AddressViewer(
                    paymentRequestAddress,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                    textAlign: TextAlign.end,
                  ),
                ),
                const Gap(4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: paymentRequestAddress),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    color: context.appColors.primary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          if (label.isNotEmpty) ...[
            SendInfoRow(
              title: context.loc.receiveNote,
              details: BullText(
                label,
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
                textAlign: .end,
              ),
            ),
            _divider(context),
          ],
          SendInfoRow(
            title: context.loc.sendSendAmount,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                CurrencyText(
                  swap.order!.payinAmountSat.toInt(),
                  showFiat: false,
                  style: context.font.bodyLarge,
                  color: context.appColors.secondary,
                ),
              ],
            ),
          ),
          _divider(context),
          SendInfoRow(
            title: context.loc.sendReceiveAmount,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                CurrencyText(
                  swap.order!.payoutAmountSat.toInt(),
                  showFiat: false,
                  style: context.font.bodyLarge,
                  color: context.appColors.secondary,
                ),
              ],
            ),
          ),
          _divider(context),
          if (networkFee != null) ...[
            SendInfoRow(
              title: context.loc.sendSendNetworkFee,
              details: CurrencyText(
                networkFee,
                showFiat: false,
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
                textAlign: TextAlign.end,
              ),
            ),
            _divider(context),
          ],
          if (swapFee != null)
            SendInfoRow(
              title: context.loc.sendTransferFee,
              details: CurrencyText(
                swapFee,
                showFiat: false,
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
                textAlign: TextAlign.end,
              ),
            ),
          if (showFeeWarning == true) ...[
            const Gap(16),
            _HighFeeWarning(feePercent),
          ],
          if (isSlowPayment == true) ...[
            const Gap(8),
            const _SlowPaymentWarning(),
          ],
          _divider(context),
        ],
      ),
    );
  }
}

class _SwapFeeBreakdown extends StatefulWidget {
  final SwapFees? fees;
  const _SwapFeeBreakdown({required this.fees});
  @override
  State<_SwapFeeBreakdown> createState() => _SwapFeeBreakdownState();
}

class _SwapFeeBreakdownState extends State<_SwapFeeBreakdown> {
  bool expanded = false;

  Widget _feeRow(BuildContext context, String label, int amt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          BullText(
            label,
            style: context.font.bodySmall,
            color: context.appColors.onSurfaceVariant,
          ),
          const Spacer(),
          CurrencyText(
            amt,
            showFiat: false,
            style: context.font.bodySmall,
            color: context.appColors.secondary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fees = widget.fees;
    final total = fees?.totalFeesMinusLockup(null) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              splashColor: context.appColors.transparent,
              splashFactory: NoSplash.splashFactory,
              highlightColor: context.appColors.transparent,
              onTap: () {
                setState(() {
                  expanded = !expanded;
                });
              },
              child: Row(
                children: [
                  BullText(
                    context.loc.sendTransferFee,
                    style: context.font.bodySmall,
                    color: context.appColors.onSurfaceVariant,
                  ),
                  const Spacer(),
                  CurrencyText(
                    total,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                  ),
                  const Gap(4),
                  Icon(
                    expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: context.appColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const Gap(12),
          if (expanded && fees != null) ...[
            Container(color: context.appColors.surface, height: 1),
            Column(
              children: [
                const Gap(4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BullText(
                    context.loc.sendTransferFeeDescription,
                    style: context.font.labelSmall,
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                if (fees.claimFee != null)
                  _feeRow(
                    context,
                    context.loc.sendReceiveNetworkFee,
                    fees.claimFee!,
                  ),
                if (fees.serverNetworkFees != null)
                  _feeRow(
                    context,
                    context.loc.sendServerNetworkFees,
                    fees.serverNetworkFees!,
                  ),
                _feeRow(context, 'Transfer Fee', fees.boltzFee ?? 0),
                const Gap(4),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChainSwapSendInfoSection extends StatelessWidget {
  const _ChainSwapSendInfoSection();
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final paymentRequestAddress = context.select(
      (SendCubit cubit) => cubit.state.paymentRequestAddress,
    );
    final legacySwap = context.select(
      (SendCubit cubit) => cubit.state.chainSwap,
    );
    final orderSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningOrder,
    );
    final swapId = orderSwap?.order?.orderNumber.toString() ?? legacySwap!.id;
    final sendAmount =
        orderSwap?.order?.payinAmountSat.toInt() ?? legacySwap!.sendAmount!;
    final receiveAmount =
        orderSwap?.order?.payoutAmountSat.toInt() ?? legacySwap?.receieveAmount;
    final feePercent = context.select(
      (SendCubit cubit) => cubit.state.getFeeAsPercentOfAmount(),
    );
    final showFeeWarning = context.select(
      (SendCubit cubit) => cubit.state.showFeeWarning,
    );
    final absoluteFees = context.select(
      (SendCubit cubit) => cubit.state.absoluteFees,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          SendInfoRow(
            title: context.loc.sendFrom,
            details: BullText(
              selectedWallet!.displayLabel(context),
              style: context.font.bodyLarge,
              color: context.appColors.secondary,
              textAlign: .end,
            ),
          ),
          _divider(context),
          SendInfoRow(
            title: context.loc.sendSwapId,
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: BullText(
                    swapId,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                    textAlign: .end,
                  ),
                ),
                const Gap(4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: swapId));
                  },
                  child: Icon(
                    Icons.copy,
                    color: context.appColors.primary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          SendInfoRow(
            title: context.loc.sendTo,
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: AddressViewer(
                    paymentRequestAddress,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                    textAlign: TextAlign.end,
                  ),
                ),
                const Gap(4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: paymentRequestAddress),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    color: context.appColors.primary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          SendInfoRow(
            title: context.loc.sendSendAmount,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                CurrencyText(
                  sendAmount,
                  showFiat: false,
                  style: context.font.bodyLarge,
                  color: context.appColors.secondary,
                ),
              ],
            ),
          ),
          _divider(context),
          if (receiveAmount != null)
            SendInfoRow(
              title: context.loc.sendReceiveAmount,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    receiveAmount,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                  ),
                ],
              ),
            ),
          if (receiveAmount != null) _divider(context),
          if (absoluteFees != null)
            SendInfoRow(
              title: context.loc.sendSendNetworkFee,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  CurrencyText(
                    absoluteFees,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.appColors.secondary,
                  ),
                ],
              ),
            ),
          if (absoluteFees != null) _divider(context),
          if (legacySwap != null)
            _SwapFeeBreakdown(fees: legacySwap.fees)
          else if (orderSwap != null &&
              orderSwap.order!.payinAmountSat >
                  orderSwap.order!.payoutAmountSat)
            SendInfoRow(
              title: context.loc.sendTransferFee,
              details: CurrencyText(
                (orderSwap.order!.payinAmountSat -
                        orderSwap.order!.payoutAmountSat)
                    .toInt(),
                showFiat: false,
                style: context.font.bodyLarge,
                color: context.appColors.secondary,
                textAlign: TextAlign.end,
              ),
            ),
          const Gap(16),

          const _SlowPaymentWarning(),

          if (showFeeWarning == true) ...[
            const Gap(8),
            _HighFeeWarning(feePercent),
          ],
          _divider(context),
        ],
      ),
    );
  }
}

class SendConfirmTopArea extends StatelessWidget {
  const SendConfirmTopArea({super.key});

  @override
  Widget build(BuildContext context) {
    final amountBitcoin = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );

    return Column(
      // crossAxisAlignment: .stretch,
      children: [
        Container(
          alignment: Alignment.center,
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: context.appColors.secondaryFixedDim,
            shape: .circle,
          ),
          child: Image.asset(
            Assets.icons.rightArrow.path,
            height: 24,
            width: 24,
          ),
        ),
        const Gap(16),
        BullText(
          context.loc.sendConfirmSend,
          style: context.font.bodyMedium,
          color: context.appColors.secondary,
        ),
        const Gap(4),
        BullText(
          amountBitcoin,
          style: context.font.displaySmall,
          color: context.appColors.secondary,
        ),
      ],
    );
  }
}

class SendSendingScreen extends StatelessWidget {
  const SendSendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLnPaid = context.select(
      (SendCubit cubit) => cubit.state.isLnInvoicePaid,
    );
    final isLnSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningOrder != null,
    );
    final isLiquid = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet!.isLiquid,
    );
    final isPayjoin = context.select(
      (SendCubit cubit) => cubit.state.payjoinSender != null,
    );
    // Same canonical getter the manual-fallback button on the transaction
    // details screen is gated on (Payjoin.canManuallyBroadcastOriginal) —
    // reusing it here, rather than a hand-rolled `proposalPsbt == null`
    // check, means this countdown can never linger past the point where a
    // proposal has arrived or the session has expired.
    final showFallbackCountdown = context.select(
      (SendCubit cubit) =>
          cubit.state.payjoinSender?.canManuallyBroadcastOriginal ?? false,
    );
    final payjoinExpiresAt = context.select(
      (SendCubit cubit) => cubit.state.payjoinSender?.expiresAt,
    );
    // Computed once per build — acceptable, the screen rebuilds on each cubit
    // emit; deliberately not adding a ticker to the bloc for this.
    final isImminent =
        payjoinExpiresAt != null &&
        payjoinExpiresAt.difference(DateTime.now()) <= const Duration(hours: 1);

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(title: _sendFlowTitle(context)),
        actions: [CloseButton(onPressed: () => _leaveSend(context))],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Align(
          child: Column(
            children: [
              const Gap(192),
              Gif(
                autostart: Autostart.loop,
                height: 123,
                image: AssetImage(Assets.animations.cubesLoading.path),
              ),
              if (!isLnSwap && !isPayjoin) ...[
                const Gap(8),
                BullText(
                  context.loc.sendSending,
                  style: context.font.headlineLarge,
                ),
                const Gap(8),
                BullText(
                  context.loc.sendBroadcastingTransaction,
                  style: context.font.bodyMedium,
                  maxLines: 4,
                  textAlign: .center,
                ),
              ],
              if (isLnSwap && !isLnPaid) ...[
                const Gap(8),
                BullText(
                  context.loc.sendSending,
                  style: context.font.headlineLarge,
                ),
                const Gap(8),
                if (isLiquid)
                  BullText(
                    context.loc.sendSwapInProgressInvoice,
                    style: context.font.bodyMedium,
                    maxLines: 4,
                    textAlign: .center,
                  )
                else
                  BullText(
                    context.loc.sendSwapInProgressBitcoin,
                    style: context.font.bodyMedium,
                    maxLines: 4,
                    textAlign: .center,
                  ),
              ],
              if (isPayjoin) ...[
                const Gap(8),
                BullText(
                  context.loc.sendSending,
                  style: context.font.headlineLarge,
                ),
                const Gap(8),
                BullText(
                  context.loc.sendCoordinatingPayjoinTransaction,
                  style: context.font.bodyMedium,
                  maxLines: 4,
                  textAlign: TextAlign.center,
                ),
                if (showFallbackCountdown &&
                    payjoinExpiresAt != null &&
                    isImminent) ...[
                  const Gap(8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BullText(
                        context.loc.sendPayjoinFallbackCountdown,
                        style: context.font.bodyMedium,
                        color: context.appColors.secondary,
                      ),
                      const Gap(4),
                      BullCountdown(until: payjoinExpiresAt),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),

      // const Spacer(flex: 2),
      // BullButton.big(
      //   label: 'Go home',
      //   onPressed: () {},
      //   bgColor: context.colour.secondary,
      //   textColor: context.colour.onSecondary,
      // ),
    );
  }
}

class SendSucessScreen extends StatelessWidget {
  const SendSucessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final amount = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountBitcoin,
    );

    final fiatEquivalent = context.select(
      (SendCubit cubit) => cubit.state.formattedConfirmedAmountFiat,
    );

    final isBitcoin = context.select(
      (SendCubit cubit) => !cubit.state.selectedWallet!.isLiquid,
    );

    final walletTransaction = context.select(
      (SendCubit cubit) => cubit.state.walletTransaction,
    );
    final payjoin = context.select(
      (SendCubit cubit) => cubit.state.payjoinSender,
    );
    final orderSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningOrder,
    );
    final chainSwap = context.select(
      (SendCubit cubit) => cubit.state.chainSwap,
    );
    final isLnSwap =
        orderSwap != null &&
        (orderSwap.inNetwork == OrderSwapNetwork.lightning ||
            orderSwap.outNetwork == OrderSwapNetwork.lightning);
    final isChainSwap = chainSwap != null || (orderSwap != null && !isLnSwap);
    // An order that expired before payin holds no funds — show expiry, not refund.
    final expiredBeforePayin =
        orderSwap != null &&
        orderSwap.localStatus == OrderSwapLocalStatus.expired &&
        orderSwap.localPayinTransactionId == null;
    // Decides whether the View Details button appears.
    final hasDetails =
        walletTransaction != null ||
        (orderSwap != null
            ? orderSwap.localPayinTransactionId != null &&
                  orderSwap.sourceWalletId != null
            : chainSwap != null || payjoin != null);
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: _sendFlowTitle(context),
          onBack: () => _leaveSend(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisAlignment: .center,
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Gap(8),
                  if (expiredBeforePayin) ...[
                    BullText(
                      context.loc.sendSwapExpiredTitle,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                    BullText(
                      context.loc.sendSwapExpiredMessage,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                  ] else if (orderSwap?.localStatus ==
                          OrderSwapLocalStatus.failed ||
                      orderSwap?.localStatus == OrderSwapLocalStatus.expired ||
                      chainSwap?.status == SwapStatus.failed ||
                      chainSwap?.status == SwapStatus.expired ||
                      chainSwap?.status == SwapStatus.refundable) ...[
                    BullText(
                      context.loc.sendSwapRefundInProgress,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                    BullText(
                      context.loc.sendSwapFailed,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                  ] else if ((orderSwap != null &&
                          orderSwap.localStatus ==
                              OrderSwapLocalStatus.refunded) ||
                      (chainSwap != null &&
                          chainSwap.status == SwapStatus.completed &&
                          chainSwap.refundTxid != null)) ...[
                    BullText(
                      context.loc.sendSwapRefundCompleted,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                    BullText(
                      context.loc.sendRefundProcessed,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                  ] else if (isLnSwap &&
                      orderSwap.localStatus ==
                          OrderSwapLocalStatus.completed) ...[
                    Gif(
                      image: AssetImage(Assets.animations.successTick.path),
                      autostart: Autostart.once,
                      height: 100,
                      width: 100,
                    ),
                    const Gap(20),
                    BullText(
                      context.loc.sendInvoicePaid,
                      style: context.font.headlineLarge,
                    ),
                  ] else if (isLnSwap &&
                      !isBitcoin &&
                      orderSwap.localStatus != OrderSwapLocalStatus.completed)
                    BullText(
                      context.loc.sendPaymentProcessing,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    )
                  else if (isLnSwap && isBitcoin)
                    BullText(
                      context.loc.sendPaymentWillTakeTime,
                      style: context.font.headlineLarge,
                    )
                  else if (isChainSwap) ...[
                    BullText(
                      context.loc.sendSwapInitiated,
                      style: context.font.bodyLarge,
                    ),
                    BullText(
                      context.loc.sendSwapWillTakeTime,
                      style: context.font.labelSmall,
                    ),
                  ] else ...[
                    BullText(
                      context.loc.sendSuccessfullySent,
                      style: context.font.bodyLarge,
                    ),
                    // A payjoin send that completed via the plain-broadcast
                    // fallback (receiver declined/expired or the payjoin
                    // negotiation failed). The user explicitly expected a
                    // payjoin, so say that it didn't happen instead of
                    // presenting the fallback as indistinguishable from a
                    // successful payjoin.
                    if (payjoin != null && payjoin.isAborted) ...[
                      const Gap(8),
                      BullText(
                        context.loc.sendSentWithoutPayjoin,
                        style: context.font.bodyMedium,
                        color: context.appColors.secondary,
                        maxLines: 4,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                  const Gap(8),
                  BullText(
                    amount,
                    style: context.font.displaySmall,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                  if (fiatEquivalent.isNotEmpty) ...[
                    const Gap(4),
                    BullText(
                      '~$fiatEquivalent',
                      style: context.font.bodyMedium,
                      color: context.appColors.secondary,
                      maxLines: 4,
                      textAlign: .center,
                    ),
                  ],
                ],
              ),
            ),
            if (orderSwap?.order?.requiresManualReview == true) ...[
              const Gap(16),
              OrderSwapUnderReviewCard(orderSwap: orderSwap!),
            ],
            const Spacer(flex: 2),
            if (hasDetails)
              BullButton.big(
                label: context.loc.sendViewDetails,
                onPressed: () {
                  if (walletTransaction != null) {
                    context.pushNamed(
                      TransactionsRoute.transactionDetails.name,
                      pathParameters: {'txId': walletTransaction.txId},
                      queryParameters: {
                        'walletId': walletTransaction.walletId,
                        'returnHome': 'true',
                      },
                    );
                  } else if (orderSwap != null) {
                    final txId = orderSwap.localPayinTransactionId;
                    final walletId = orderSwap.sourceWalletId;
                    if (txId != null && walletId != null) {
                      context.pushNamed(
                        TransactionsRoute.transactionDetails.name,
                        pathParameters: {'txId': txId},
                        queryParameters: {
                          'walletId': walletId,
                          'returnHome': 'true',
                        },
                      );
                    }
                  } else if (chainSwap != null) {
                    context.pushNamed(
                      TransactionsRoute.swapTransactionDetails.name,
                      pathParameters: {'swapId': chainSwap.id},
                      queryParameters: {
                        'walletId': chainSwap.walletId,
                        'returnHome': 'true',
                      },
                    );
                  } else if (payjoin != null) {
                    // Navigate by the on-chain txid, NOT payjoin.id: a
                    //  sender's id IS the full BIP21 URI (address+amount) and
                    //  would leak into the router location string. By this
                    //  point the session is terminal, so txId (real payjoin)
                    //  or originalTxId (fallback) is always the broadcast tx —
                    //  and landing on the real transaction is better UX than
                    //  the session placeholder.
                    context.pushNamed(
                      TransactionsRoute.transactionDetails.name,
                      pathParameters: {
                        'txId': payjoin.txId ?? payjoin.originalTxId,
                      },
                      queryParameters: {
                        'walletId': payjoin.walletId,
                        'returnHome': 'true',
                      },
                    );
                  }
                },
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
              ),
            const Gap(32),
          ],
        ),
      ),
    );
  }
}

void _leaveSend(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
