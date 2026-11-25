import 'package:swaps/order_swaps.dart';
import 'package:primitives/primitives.dart'
    as chains
    show BitcoinNetwork, LiquidNetwork;
import 'package:silent/localizations.dart';
import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:signers/signers.dart';
import 'package:send/src/payment/public/send_psbt_handoff.dart';

import '../widgets/send_leave_payment_dialog.dart';
import '../widgets/send_grouped_address.dart';

import 'dart:async';

import '../../domain/send_source.dart';
import '../send_payment_ui.dart';
import 'send_payment_page.dart';
import 'send_payment_review.dart';
import '../widgets/send_payment_settings.dart';
import '../widgets/send_custom_fee_editor.dart';
import '../widgets/send_whole_balance_dialog.dart';
import '../../domain/send_custom_fee_policy.dart';
import 'send_payment_animation_policy.dart';

import '../widgets/send_ark_routing_actions.dart';

import 'package:primitives/primitives.dart'
    show BitcoinUnit, FormatAmount, Sats;

import 'dart:math' as math;

import 'package:send/src/payment/domain/internal_recipient_policy.dart';

import 'package:fees/fees.dart';
import 'package:address_view/payment_destination.dart'
    show FullScreenScannerPage;
import 'package:swaps/swaps.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:send/src/send_localizations.dart';
import 'package:send/src/payment/presentation/onchain_send_labels_l10n.dart';
import 'package:satoshifier/payment_request.dart'
    show Bip21PaymentRequest, BitcoinPaymentRequest, LiquidPaymentRequest;
import 'package:bull_logger/bull_logger.dart';

import 'package:label_editor/label_editor.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/presentation/send_failure_l10n.dart';
import 'package:send/src/payment/presentation/send_wallet_view.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:send/src/payment/ui/widgets/advanced_options_bottom_sheet.dart';
import 'package:send/src/payment/ui/widgets/multi_recipient_transaction_review.dart';
import 'package:send/src/payment/ui/widgets/recipient_fields.dart';
import 'package:send/src/payment/ui/widgets/send_info_row.dart';
import 'package:transactions/routes.dart';
import 'package:send/send.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAlertCard,
        BullAmount,
        BullKeyboardActions,
        BullOnchainSendInfoSection,
        BullAdvancedOptionsLink,
        BullFieldAction,
        BullIcons,
        BullSpacing,
        BullThemeX,
        BullPickerSheet,
        BullAmountInput,
        BullAmountCurrency,
        BullAmountInputValue,
        BullAmountUnitToggle,
        BullAmountScope,
        showBullDropdownMenu,
        BullUiLocalizations,
        BullBorderedTile,
        BullBottomSheet,
        BullButton,
        BullCountdown,
        BullDialog,
        BullPaymentDestinationInput,
        BullSwitch,
        BullTypographyX,
        BullDropdown,
        BullFadingLinearProgress,
        BullInfoCard,
        BullLoader,
        BullPaymentNetwork,
        BullPaymentPhase,
        BullPaymentTransition,
        BullPickerItem,
        BullSegmented,
        BullSnackBar,
        BullText,
        BullTopBar,
        Gap;
import 'package:go_router/go_router.dart';

part 'send_payment_binding.dart';

String _sendFlowTitle(BuildContext context) {
  final isSweep = context.select((SendCubit cubit) => cubit.state.isSweep);
  return isSweep ? context.loc.coinsSweepTitle : context.loc.sendTitle;
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  bool multipleRecipients = false;
  late final _SendPaymentSession _payment;
  bool _transitionVisible = false;
  bool _confirmInFlight = false;
  bool _expectsSwap = false;
  String? _previousTxId;

  @override
  void initState() {
    super.initState();
    _payment = _SendPaymentSession(context.read<SendCubit>(), _confirm);
  }

  Future<void> _confirm() async {
    final cubit = context.read<SendCubit>();
    if (_confirmInFlight) return;
    _confirmInFlight = true;
    if (cubit.state.willAttemptPayjoin || cubit.state.payjoinSender != null) {
      try {
        await cubit.onConfirmTransactionClicked();
      } finally {
        _confirmInFlight = false;
      }
      return;
    }
    setState(() {
      _transitionVisible = true;
      _previousTxId = cubit.state.txId;
      _expectsSwap =
          cubit.state.sendType == SendType.lightning ||
          cubit.state.requireChainSwap ||
          cubit.state.lightningOrder != null ||
          cubit.state.boltzSendSwap != null;
    });
    try {
      await cubit.onConfirmTransactionClicked();
    } finally {
      _confirmInFlight = false;
      if (mounted) {
        final state = cubit.state;
        final uncertain =
            state.hasBroadcastFailure ||
            state.lightningOrder?.localStatus ==
                OrderSwapLocalStatus.broadcastUnknown;
        setState(() {
          if (uncertain ||
              (state.failure != null && !_isPreBroadcastFailure(state)) ||
              (state.step == SendStep.confirm &&
                  _terminalPhase(state) == null)) {
            _transitionVisible = false;
          }
        });
      }
    }
  }

  BullPaymentPhase? _terminalPhase(SendState state) {
    final order = state.lightningOrder;
    if (order != null) {
      return orderPaymentPhase(
        order.localStatus,
        hasFundsMoved: order.hasFundsMoved,
      );
    }
    final swap = state.boltzSendSwap;
    if (swap != null) {
      return boltzPaymentPhase(
        swap.status,
        refunded: switch (swap) {
          ChainSwap(:final refundTxid) ||
          LnSendSwap(:final refundTxid) => refundTxid != null,
          _ => false,
        },
        completedProven: switch (swap) {
          ChainSwap(:final receiveTxid) => receiveTxid?.isNotEmpty ?? false,
          LnSendSwap() => true,
          _ => false,
        },
      );
    }
    if (_isPreBroadcastFailure(state)) return BullPaymentPhase.failed;
    return directPaymentSucceeded(
          expectsSwap: _expectsSwap,
          previousTxId: _previousTxId,
          transactionId: state.txId,
          hasPayjoin: state.payjoinSender != null,
        )
        ? BullPaymentPhase.success
        : null;
  }

  bool _isPreBroadcastFailure(SendState state) =>
      !_expectsSwap &&
      state.txId == null &&
      state.payjoinSender == null &&
      state.hasBuildFailure;

  String _transitionStatus(
    BuildContext context,
    SendState state,
    BullPaymentPhase? terminal,
  ) {
    final loc = context.loc;
    final orderStatus = state.lightningOrder?.localStatus;
    final swap = state.boltzSendSwap;
    final refundBroadcast = switch (swap) {
      ChainSwap(:final refundTxid) ||
      LnSendSwap(:final refundTxid) => refundTxid != null,
      _ => false,
    };
    if (terminal == BullPaymentPhase.success) return loc.sendSuccessfullySent;
    if (terminal == BullPaymentPhase.failed) {
      if (_isPreBroadcastFailure(state)) {
        return state.failure?.toTranslated(context) ??
            loc.oopsSomethingWentWrong;
      }
      if (refundBroadcast ||
          orderStatus == OrderSwapLocalStatus.refunded ||
          swap?.status == SwapStatus.refunded) {
        return loc.sendSwapRefundCompleted;
      }
      return orderStatus == OrderSwapLocalStatus.expired
          ? loc.sendSwapExpiredTitle
          : loc.sendSwapFailed;
    }
    return switch (swap?.status ?? orderStatus) {
      SwapStatus.refundable ||
      SwapStatus.failed ||
      SwapStatus.expired ||
      OrderSwapLocalStatus.failed ||
      OrderSwapLocalStatus.expired => loc.sendSwapRefundInProgress,
      _ => _expectsSwap ? loc.sendPaymentProcessing : loc.sendSending,
    };
  }

  void _dismissTransition() {
    if (mounted) setState(() => _transitionVisible = false);
  }

  TransactionDetailsTarget? _detailsTarget(SendState state) {
    final order = state.lightningOrder;
    if (order != null) return TransactionDetailsTarget.orderSwap(order.localId);
    final swap = state.boltzSendSwap;
    if (swap != null) {
      return TransactionDetailsTarget.swap(swap.id, walletId: swap.walletId);
    }
    if (_expectsSwap) return null;
    final txId = state.txId;
    final walletId = state.selectedWallet?.id;
    if (txId == null || txId == _previousTxId || walletId == null) return null;
    return TransactionDetailsTarget.wallet(txId, walletId: walletId);
  }

  Future<void> _openTransitionDetails() async {
    if (!_transitionVisible) return;
    final target = _detailsTarget(context.read<SendCubit>().state);
    _dismissTransition();
    if (target != null) {
      await TransactionsNavigation.openDetails(
        context,
        target,
        returnHome: true,
      );
    }
  }

  @override
  void dispose() {
    _payment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final content = BlocListener<SendCubit, SendState>(
      listener: (_, state) => _payment.update(state),
      child: _content(context, state),
    );
    final terminal = _terminalPhase(state);
    final showTransition =
        _transitionVisible &&
        (state.failure == null || _isPreBroadcastFailure(state)) &&
        state.lightningOrder?.localStatus !=
            OrderSwapLocalStatus.broadcastUnknown;
    final network = switch (state.lightningOrder?.outNetwork) {
      OrderSwapNetwork.bitcoin => BullPaymentNetwork.bitcoin,
      OrderSwapNetwork.lightning => BullPaymentNetwork.lightning,
      OrderSwapNetwork.liquid => BullPaymentNetwork.liquid,
      null => switch (state.sendType) {
        SendType.bitcoin => BullPaymentNetwork.bitcoin,
        SendType.lightning => BullPaymentNetwork.lightning,
        SendType.liquid => BullPaymentNetwork.liquid,
      },
    };
    return PopScope<Object?>(
      canPop: !showTransition,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showTransition) _dismissTransition();
      },
      child: Stack(
        children: [
          ExcludeSemantics(
            excluding: showTransition,
            child: ExcludeFocus(
              excluding: showTransition,
              child: IgnorePointer(ignoring: showTransition, child: content),
            ),
          ),
          if (showTransition)
            Positioned.fill(
              child: BullPaymentTransition(
                network: network,
                phase: terminal ?? BullPaymentPhase.sending,
                status: _transitionStatus(context, state, terminal),
                skipLabel: _detailsTarget(state) != null && !_expectsSwap
                    ? context.loc.sendViewDetails
                    : BullUiLocalizations.of(context).paymentViewStatus,
                onSkip: _openTransitionDetails,
                onBackdropTap: _dismissTransition,
                onDone: () {
                  if (_terminalPhase(context.read<SendCubit>().state) != null) {
                    _dismissTransition();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, SendState state) {
    final step = state.step;
    if (_payment.supports(state) &&
        (step == SendStep.address ||
            step == SendStep.amount ||
            step == SendStep.confirm)) {
      return _payment.build(context, state);
    }
    switch (step) {
      case SendStep.address:
        return SendAddressScreen(
          multipleRecipients: multipleRecipients,
          onToggle: (value) => setState(() => multipleRecipients = value),
        );
      case SendStep.amount:
        return const SendAmountScreen();
      case SendStep.confirm:
        return const SendConfirmScreen();
      case SendStep.sending:
        return const SendSendingScreen();
      case SendStep.success:
        return const SendSucessScreen();
    }
  }
}

class SendAddressScreen extends StatelessWidget {
  const SendAddressScreen({
    super.key,
    this.multipleRecipients = false,
    this.onToggle,
  });

  final bool multipleRecipients;
  final ValueChanged<bool>? onToggle;

  Future<void> _toggle(
    BuildContext context,
    bool value,
    SendCubit cubit,
  ) async {
    if (!value && cubit.state.recipientDrafts.length > 1) {
      final confirmed = await BullDialog.show<bool>(
        context: context,
        builder: (dialogContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.loc.sendRemoveOtherRecipients,
              style: context.bullType.subtitle,
            ),
            const Gap(12),
            Text(
              context.loc.sendRemoveOtherRecipientsMessage,
              style: context.bullType.body,
            ),
            const Gap(20),
            Row(
              children: [
                Expanded(
                  child: BullButton.secondary(
                    label: context.loc.cancel,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: BullButton.primary(
                    label: context.loc.sendRemove,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      for (final recipient in cubit.state.recipientDrafts.skip(1).toList()) {
        cubit.removeRecipient(recipient.id);
      }
    }
    if (!value) cubit.cancelPendingInternalRecipient();
    onToggle?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final cubit = context.read<SendCubit>();
    final isLiquidRequest = switch (state.paymentRequest) {
      Bip21PaymentRequest(:final network) => network is chains.LiquidNetwork,
      _ => state.paymentRequest?.isLiquidAddress == true,
    };
    final canToggle =
        !cubit.isSpMode &&
        !state.selectedInputsUnavailable &&
        !(state.usesSelectedInputsOnly &&
            state.selectedWallet?.isLiquid == true) &&
        (state.paymentRequest == null || state.canAddRecipient);
    final canAdd =
        multipleRecipients &&
        state.canAddRecipient &&
        state.recipientDrafts.isNotEmpty &&
        state.recipientDrafts.every((recipient) => recipient.isValid) &&
        !state.addingInternalRecipient;
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: _sendFlowTitle(context),
          color: context.appColors.background,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            BullFadingLinearProgress(
              height: 3,
              trigger: state.loadingBestWallet || state.creatingSwap,
              backgroundColor: context.appColors.onSecondary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RecipientAddressFields(
                      recipients: state.recipientDrafts,
                      multipleRecipients: multipleRecipients,
                      internalRecipientWallets: state.internalRecipientWallets,
                      primaryField: AddressField(
                        multipleRecipients: multipleRecipients,
                      ),
                      onRemoveRecipient: cubit.removeRecipient,
                      onAddressChanged: cubit.recipientAddressChanged,
                    ),
                    AddRecipientButton(
                      canAdd: canAdd,
                      onAdd: () async {
                        await cubit.addRecipient();
                      },
                      onMyWallet: () => _showWalletSheet(context, cubit),
                    ),
                    const AddressErrorSection(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.appColors.border),
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.loc.sendMultipleRecipients,
                                style: context.bullType.body,
                              ),
                              Text(
                                canToggle
                                    ? context.loc.sendMultipleRecipientsHint
                                    : cubit.isSpMode
                                    ? context.loc.sendMultipleUnavailableSilent
                                    : state.paymentRequest?.isBolt11 == true ||
                                          state.paymentRequest?.isLnAddress ==
                                              true
                                    ? context
                                          .loc
                                          .sendMultipleUnavailableLightning
                                    : isLiquidRequest
                                    ? context.loc.sendMultipleUnavailableLiquid
                                    : (state.paymentRequest?.amountSat ?? 0) > 0
                                    ? context.loc.sendMultipleUnavailableAmount
                                    : context.loc.sendMultipleUnavailable,
                                style: context.bullType.label.copyWith(
                                  color: context.appColors.textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        BullSwitch(
                          value: multipleRecipients,
                          onChanged:
                              (canToggle || multipleRecipients) &&
                                  onToggle != null
                              ? (value) => _toggle(context, value, cubit)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  const SendArkRoutingActions(
                    fallback: SendContinueWithAddressButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showWalletSheet(BuildContext context, SendCubit cubit) async {
  final state = cubit.state;
  final network = const InternalRecipientPolicy().network(state.paymentRequest);
  if (network == null) return;
  final wallets = state.wallets
      .where(
        (wallet) =>
            wallet.network.env == network.env &&
            (wallet.isLiquid ||
                const InternalRecipientPolicy().permits(
                  wallet,
                  state.paymentRequest,
                  fixedSourceWalletId: state.usesSelectedInputsOnly
                      ? state.selectedWallet?.id
                      : null,
                )),
      )
      .toList();
  final selected = await showModalBottomSheet<SendSource>(
    context: context,
    backgroundColor: context.appColors.onSecondary,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.loc.sendToMyWallet, style: context.bullType.subtitle),
            const Gap(4),
            Text(
              context.loc.sendMyWalletAddressHint,
              style: context.bullType.label.copyWith(
                color: context.appColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Gap(20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final wallet in wallets) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: context.appColors.surface,
                          border: Border(
                            left: BorderSide(
                              color: wallet.tagColor(context),
                              width: 6,
                            ),
                            top: BorderSide(color: context.appColors.border),
                            right: BorderSide(color: context.appColors.border),
                            bottom: BorderSide(color: context.appColors.border),
                          ),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            title: Text(
                              wallet.displayLabel(context),
                              style: context.bullType.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              wallet.isLiquid
                                  ? context.loc.sendLiquidUnavailable
                                  : wallet.typeLabel(context),
                              style: context.bullType.label.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            onTap: wallet.isLiquid
                                ? null
                                : () => Navigator.of(sheetContext).pop(wallet),
                          ),
                        ),
                      ),
                      const Gap(8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (selected != null && context.mounted) {
    await cubit.addInternalRecipient(selected.id);
  }
}

class SendContinueWithAddressButton extends StatelessWidget {
  const SendContinueWithAddressButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    return BullButton.primary(
      label: context.loc.sendContinue,
      onPressed:
          (state.copiedRawPaymentRequest.trim().isEmpty ||
              state.hasInvalidAdditionalRecipient ||
              state.addingInternalRecipient ||
              state.loadingBestWallet ||
              state.creatingSwap ||
              state.selectedInputsUnavailable)
          ? null
          : () => context.read<SendCubit>().continueOnAddressConfirmed(),
    );
  }
}

class AddressField extends StatelessWidget {
  const AddressField({
    super.key,
    this.multipleRecipients = false,
    this.onInput,
    this.onScanned,
    this.showLabel = true,
  });

  final bool multipleRecipients;
  final Future<void> Function(String)? onInput;
  final Future<void> Function(String)? onScanned;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final cubit = context.read<SendCubit>();
    final request = state.paymentRequest;
    final isBitcoinRequest = switch (request) {
      Bip21PaymentRequest(:final network) => network is chains.BitcoinNetwork,
      _ => request?.isBitcoinAddress == true,
    };
    final kind = cubit.isSpMode
        ? context.loc.sendSilentPaymentAddress
        : request?.isPsbt == true
        ? context.loc.sendPsbtRequest
        : request?.isBolt11 == true
        ? context.loc.sendLightningInvoice
        : request?.isLnAddress == true
        ? context.loc.exchangeDcaAddressLabelLightning
        : isBitcoinRequest
        ? context.loc.exchangeDcaAddressLabelBitcoin
        : context.loc.exchangeDcaAddressLabelLiquid;
    final amount = request?.amountSat;
    return BullPaymentDestinationInput(
      label: showLabel ? context.loc.sendRecipientAddress : null,
      value: state.copiedRawPaymentRequest,
      enabled: !state.selectedInputsUnavailable,
      hint: context.loc.sendPasteAddressOrInvoice,
      onChanged: onInput ?? cubit.onChangedText,
      pasteLabel: MaterialLocalizations.of(context).pasteButtonLabel,
      scanLabel: context.silentLoc.silentScan,
      clearLabel: context.silentLoc.silentClearButton,
      onClear: () => (onInput ?? cubit.onChangedText)(''),
      onPaste: () async {
        final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
        final text = clipboard?.text;
        if (context.mounted && text != null) {
          await (onInput ?? cubit.onChangedText)(text);
        }
      },
      onScan: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => FullScreenScannerPage(
            onScannedPaymentRequest:
                onScanned ??
                (raw) => cubit.onScannedPaymentRequest(
                  raw,
                  autoContinue: !multipleRecipients,
                ),
          ),
        ),
      ),
      validAddress: request == null
          ? null
          : AddressViewer(
              state.paymentRequestAddress,
              clipboardText: state.copiedRawPaymentRequest,
              style: context.bullType.body,
            ),
      error: state.failure is SendInvalidPaymentRequestFailure
          ? state.failure?.toTranslated(context)
          : null,
      kind: amount != null && amount > 0
          ? request?.isBolt11 == true
                ? context.loc.sendLightningInvoiceAmount(amount)
                : context.loc.destinationAmountFromQr(kind, amount)
          : kind,
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
    if (failure != null && failure is! SendInvalidPaymentRequestFailure) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: BullText(
          failure.toTranslated(
            context,
            formattedFrozenBalance: frozenBalanceHint,
          ),
          style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
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
  String? _multiCurrency;
  BitcoinUnit? _multiGlobalUnit;
  int? _multiGlobalGeneration;

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

  Widget _multiAmountHeader(BuildContext context, SendState state) {
    final code = _multiCurrency ?? state.bitcoinUnit?.code ?? 'sats';
    final bitcoin = code == 'BTC' || code == 'sats';
    final unit = code == 'BTC' ? BitcoinUnit.btc : BitcoinUnit.sats;
    final style = context.bullType.body.copyWith(fontWeight: FontWeight.w500);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.loc.amountInputHeader,
          style: context.bullType.label.copyWith(
            color: context.appColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(4),
        if (bitcoin)
          BullAmountUnitToggle(
            text: code,
            unit: unit,
            style: style,
            onPressed: () => setState(
              () => _multiCurrency = unit == BitcoinUnit.btc ? 'sats' : 'BTC',
            ),
          ),
        Builder(
          builder: (anchor) => IconButton(
            tooltip: context.loc.settingsCurrencyTitle,
            icon: bitcoin
                ? Icon(
                    Icons.arrow_drop_down,
                    color: context.appColors.text,
                    size: 24,
                  )
                : Text('$code ▾', style: style),
            onPressed: () async {
              final l10n = BullUiLocalizations.of(context);
              final scope = BullAmountScope.maybeOf(context);
              final showPreference =
                  scope?.snapshot.isReady == true &&
                  scope?.canWriteInputMode == true &&
                  (bitcoin || code == state.fiatCurrencyCode);
              final checked = scope?.snapshot.startInFiat == !bitcoin;
              final items = [
                BullPickerItem(value: 'bitcoin', label: l10n.amountBitcoin),
                for (final currency in [
                  ...SupportedCurrency.values.where(
                    (c) => c.code == state.fiatCurrencyCode,
                  ),
                  ...SupportedCurrency.values.where(
                    (c) => c.code != state.fiatCurrencyCode,
                  ),
                ])
                  BullPickerItem(
                    value: currency.code,
                    label: currency.code,
                    enabled: state.amountQuotes.containsKey(currency),
                    disabledReason: state.amountQuotes.containsKey(currency)
                        ? null
                        : l10n.amountNoPrice,
                  ),
                if (showPreference)
                  BullPickerItem(
                    value: 'initial-mode',
                    label: l10n.amountAlwaysStartIn(
                      bitcoin ? l10n.amountBitcoin : code,
                    ),
                    checked: checked,
                    dividerBefore: true,
                  ),
              ];
              final index = await showBullDropdownMenu<String>(
                anchor: anchor,
                value: bitcoin ? 'bitcoin' : code,
                items: items,
              );
              final selected = index == null ? null : items[index].value;
              if (selected == null || !mounted) return;
              if (selected == 'initial-mode' && scope != null) {
                await scope.changeDefaultInputMode(
                  checked ? bitcoin : !bitcoin,
                  bitcoinMessage: l10n.amountStartChanged(l10n.amountBitcoin),
                  fiatMessage: l10n.amountStartChanged(state.fiatCurrencyCode),
                  failureMessage: l10n.amountPreferenceChangeFailed,
                );
                return;
              }
              setState(
                () => _multiCurrency = selected == 'bitcoin'
                    ? (state.bitcoinUnit?.code ?? 'sats')
                    : selected,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopeData = BullAmountScope.maybeOf(context);
    final scope = scopeData?.snapshot;
    if (scope != null &&
        scope.isReady &&
        (scope.unit != _multiGlobalUnit ||
            scopeData?.generation != _multiGlobalGeneration)) {
      final first = _multiGlobalUnit == null;
      _multiGlobalUnit = scope.unit;
      _multiGlobalGeneration = scopeData?.generation;
      _multiCurrency = first && scope.startInFiat
          ? scope.defaultCurrencyCode
          : scope.unit.code;
    }
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
          onBack: () => context.read<SendCubit>().backClicked(),
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
            child: BullKeyboardActions(
              doneText: context.loc.doneButton,
              disableScroll: true,
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

                    final totalCurrency =
                        SupportedCurrency.tryFromCode(_multiCurrency ?? '') ??
                        SupportedCurrency.tryFromCode(state.fiatCurrencyCode);
                    final totalQuote = totalCurrency == null
                        ? null
                        : state.amountQuotes[totalCurrency];
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
                    final request = state.paymentRequest;
                    final fixedAmount = state.hasFixedRequestAmount;
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
                                  if (!state.showsRecipientAmountList) ...[
                                    const Gap(16),
                                    BullBorderedTile(
                                      onTap: () => context
                                          .read<SendCubit>()
                                          .backClicked(),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  context.loc.sendTo,
                                                  style: context.bullType.label
                                                      .copyWith(
                                                        color: context
                                                            .appColors
                                                            .textMuted,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                ),
                                                if (request?.isBolt11 == true)
                                                  Text(
                                                    (request?.amountSat ?? 0) >
                                                            0
                                                        ? context.loc
                                                              .sendLightningInvoiceAmount(
                                                                request?.amountSat ??
                                                                    0,
                                                              )
                                                        : context
                                                              .loc
                                                              .sendLightningInvoice,
                                                    style:
                                                        context.bullType.body,
                                                  )
                                                else
                                                  AddressViewer(
                                                    state.paymentRequestAddress,
                                                    style:
                                                        context.bullType.body,
                                                    clipboardText: state
                                                        .copiedRawPaymentRequest,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: context.appColors.text,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Gap(24),
                                  ],
                                  Text(
                                    context.loc.sendFrom,
                                    style: context.bullType.body,
                                  ),
                                  const Gap(8),
                                  ColoredBox(
                                    color: context.appColors.background,
                                    // The dropdown draws its own border, aligned with
                                    // the recipient tile; only bare text is inset.
                                    child:
                                        state.usesSelectedInputsOnly ||
                                            pickableWallet == null
                                        ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12.0,
                                            ),
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                minHeight: 48,
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  selectedWallet.displayLabel(
                                                    context,
                                                  ),
                                                  style: context
                                                      .bullType
                                                      .subtitle
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          )
                                        : BullDropdown<String>(
                                            value: selectedWallet.id,
                                            items: [
                                              for (final w in wallets)
                                                BullPickerItem(
                                                  value: w.id,
                                                  label: w.displayLabel(
                                                    context,
                                                  ),
                                                ),
                                            ],
                                            onChanged: (walletId) => context
                                                .read<SendCubit>()
                                                .updateSelectedWallet(
                                                  wallets.firstWhere(
                                                    (wallet) =>
                                                        wallet.id == walletId,
                                                  ),
                                                ),
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: RichText(
                                            text: TextSpan(
                                              style: context.bullType.label
                                                  .copyWith(
                                                    color: context
                                                        .appColors
                                                        .textMuted,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      state
                                                          .usesSelectedInputsOnly
                                                      ? context
                                                            .loc
                                                            .sendSelectedCoinsLabel
                                                      : context
                                                            .loc
                                                            .addressViewBalance,
                                                ),
                                                TextSpan(
                                                  text:
                                                      ' ${state.formattedWalletBalance()}',
                                                  style: context.bullType.label
                                                      .copyWith(
                                                        color: context
                                                            .appColors
                                                            .text,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (!fixedAmount &&
                                            !isLightning &&
                                            !isChainSwap &&
                                            !state.hasMultipleRecipients)
                                          Row(
                                            children: [
                                              Text(
                                                context.loc.swapMax,
                                                style: context.bullType.label,
                                              ),
                                              const Gap(8),
                                              BullSwitch(
                                                value: state.isMaxSend,
                                                onChanged: (value) {
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
                                                    _amountFocusNode
                                                        .requestFocus();
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (state.showsRecipientAmountList)
                                    RecipientAmounts(
                                      amountHeader: _multiAmountHeader(
                                        context,
                                        state,
                                      ),
                                      amountFieldBuilder:
                                          (recipient, focusNode) =>
                                              _RecipientKitAmount(
                                                key: ValueKey(recipient.id),
                                                amount: recipient.amount,
                                                canonicalUnit:
                                                    BitcoinUnit.fromCode(
                                                      inputCurrency,
                                                    ),
                                                currencyCode:
                                                    _multiCurrency ??
                                                    state.bitcoinUnit?.code ??
                                                    'sats',
                                                defaultCurrencyCode:
                                                    state.fiatCurrencyCode,
                                                quotes: state.amountQuotes,
                                                focusNode: focusNode,
                                                onChanged: (entry) => context
                                                    .read<SendCubit>()
                                                    .recipientEntryChanged(
                                                      recipient.id,
                                                      entry.sats,
                                                      isValid: entry.isValid,
                                                      isEdit: entry.isEdit,
                                                      currencyCode:
                                                          entry.currencyCode,
                                                      text: entry.text,
                                                      rate: entry.price,
                                                      quotedAt: entry.priceAt,
                                                    ),
                                              ),
                                      recipients: state.recipientDrafts,
                                      preparedAmounts:
                                          state.recipientAmountsSat,
                                      internalRecipientWallets:
                                          state.internalRecipientWallets,
                                      qrAmountRecipientIds:
                                          state.qrAmountRecipientIds,
                                      feeSat: state.feePreviewCache
                                          .slotFor(state.selectedFeeOption)
                                          .feeSat,
                                      fixedTotalSat:
                                          state.totalFixedRecipientAmountSat,
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
                                      amountBuilder: (amountSat) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          BullAmount.signedSats(
                                            amountSat,
                                            color: context.appColors.textMuted,
                                            style: context.bullType.body,
                                            interactive: false,
                                          ),
                                          if (totalQuote case final quote?)
                                            Text(
                                              '≈ ${FormatAmount.fiat(quote.fiatValueOf(BigInt.from(amountSat)), quote.currency.code)}',
                                              style: context.bullType.caption
                                                  .copyWith(
                                                    color: context
                                                        .appColors
                                                        .textMuted,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    )
                                  else if (fixedAmount)
                                    Column(
                                      children: [
                                        const Gap(32),
                                        BullAmount.signedSats(
                                          state.effectiveAmountSat,
                                          interactive: true,
                                          style: context.bullType.display,
                                          color: context.appColors.text,
                                          overrideHideAmounts: true,
                                        ),
                                        const Gap(8),
                                        Text(
                                          context.loc.sendAmountSetByRequest,
                                          style: context.bullType.label
                                              .copyWith(
                                                color:
                                                    context.appColors.textMuted,
                                                fontWeight: FontWeight.w400,
                                              ),
                                        ),
                                        if (failure != null) ...[
                                          const Gap(8),
                                          Text(
                                            failure.toTranslated(
                                              context,
                                              formattedFrozenBalance:
                                                  frozenBalanceHint,
                                            ),
                                            style: context.bullType.label
                                                .copyWith(
                                                  color:
                                                      context.appColors.error,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                          ),
                                        ],
                                      ],
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        BullAmountInput(
                                          canonicalUnit: BitcoinUnit.fromCode(
                                            inputCurrency,
                                          ),
                                          amountController: _amountController,
                                          defaultCurrencyCode:
                                              state.fiatCurrencyCode,
                                          currencies: [
                                            for (final currency
                                                in SupportedCurrency.values)
                                              BullAmountCurrency(
                                                code: currency.code,
                                                decimals: currency.decimals,
                                                price: state
                                                    .amountQuotes[currency]
                                                    ?.fiatAmount,
                                                priceAt: state
                                                    .amountQuotes[currency]
                                                    ?.fetchedAt,
                                              ),
                                          ],
                                          onEntryChanged: (entry) => context
                                              .read<SendCubit>()
                                              .amountEntryChanged(
                                                sats: entry.sats,
                                                currencyCode:
                                                    entry.currencyCode,
                                                text: entry.text,
                                                rate: entry.price,
                                                quotedAt: entry.priceAt,
                                                isValid: entry.isValid,
                                                isEdit: entry.isEdit,
                                              ),
                                          error: failure?.toTranslated(
                                            context,
                                            formattedFrozenBalance:
                                                frozenBalanceHint,
                                          ),
                                          focusNode: _amountFocusNode,
                                          isMax: state.isMaxSend,
                                          maxLoading:
                                              state.isMaxSend &&
                                              context
                                                      .read<SendCubit>()
                                                      .preparedMaxAmountSat ==
                                                  null,
                                          maxAmountSat: switch (context
                                              .read<SendCubit>()
                                              .preparedMaxAmountSat) {
                                            final amount? => BigInt.from(
                                              amount,
                                            ),
                                            null => null,
                                          },
                                        ),
                                        if (state.lnurlPayLimits
                                            case final limits?
                                            when failure
                                                is! SendLnurlAmountOutOfBoundsFailure) ...[
                                          const Gap(8),
                                          Text(
                                            context.loc.sendLnurlAmountRange(
                                              limits.minimumSat,
                                              limits.maximumSat,
                                            ),
                                            style: context.bullType.caption
                                                .copyWith(
                                                  color: context
                                                      .appColors
                                                      .textMuted,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  if (suggestsInstantPayments)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: BullText(
                                        context
                                            .loc
                                            .sendErrorAmountBelowSwapLimitsBitcoin,
                                        style: context.bullType.label.copyWith(
                                          fontWeight: FontWeight.w400,
                                        ),
                                        color: context.appColors.error,
                                        maxLines: 3,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  Gap(Device.screen.height * 0.02),
                                  BullBorderedTile(
                                    onTap: () async {
                                      final cubit = context.read<SendCubit>();
                                      final saved = await LabelEditor.label(
                                        context,
                                        title:
                                            context.loc.transactionNoteAddTitle,
                                        initialValue: state.label.isEmpty
                                            ? null
                                            : state.label,
                                        hint: context.loc.transactionNoteHint,
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
                                                style: context.bullType.body
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
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
                                                style: context.bullType.body,
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
                                  if (state.consolidationRequired) ...[
                                    const Gap(16),
                                    BullAlertCard(
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
                                    const _SendError(),
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
      (SendCubit cubit) => cubit.state.effectiveAmountSat,
    );
    final recipientAmountsValid = context.select(
      (SendCubit cubit) =>
          !cubit.state.usesRecipientList || cubit.state.hasValidRecipientDrafts,
    );
    final usesRecipientList = context.select(
      (SendCubit cubit) => cubit.state.usesRecipientList,
    );
    return BullButton.primary(
      label: context.loc.sendContinue,
      onPressed:
          (amountConfirmedClicked ||
              creatingSwap ||
              loadingBestWallet ||
              !context.select(
                (SendCubit cubit) => cubit.state.hasValidAmountEntry,
              ) ||
              !recipientAmountsValid ||
              (!usesRecipientList && inputAmountSat <= 0))
          ? null
          : () {
              final cubit = context.read<SendCubit>();
              final currentAmount = amountController.text;
              final fixedAmount = cubit.state.hasFixedRequestAmount;
              if (!fixedAmount &&
                  !cubit.state.usesRecipientList &&
                  currentAmount != cubit.state.amount) {
                cubit.amountChanged(amount: currentAmount);
              }
              cubit.onAmountConfirmed();
            },
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
    final hasBoltzLightningSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningSwap != null,
    );
    final isLnSwap =
        hasBoltzLightningSwap ||
        (orderSwap != null &&
            (orderSwap.inNetwork == OrderSwapNetwork.lightning ||
                orderSwap.outNetwork == OrderSwapNetwork.lightning));
    final isChainSwap =
        context.select((SendCubit cubit) => cubit.state.chainSwap != null) ||
        (orderSwap != null && !isLnSwap);
    final isLiquid = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.isLiquid ?? false,
    );
    final isUnconfidentialLiquidDestination = context.select(
      (SendCubit cubit) => cubit.state.isUnconfidentialLiquidDestination,
    );
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: _sendFlowTitle(context),
          onBack: () => context.read<SendCubit>().backClicked(),
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
                    if (context.select(
                          (SendCubit cubit) => cubit.state.confirmedConversion,
                        )
                        case final conversion?) ...[
                      const Gap(8),
                      Text(
                        context.loc.amountEnteredAtRate(
                          conversion.enteredText,
                          conversion.currencyCode,
                          MaterialLocalizations.of(context).formatTimeOfDay(
                            TimeOfDay.fromDateTime(
                              conversion.quotedAt.toLocal(),
                            ),
                            alwaysUse24HourFormat: true,
                          ),
                        ),
                        style: context.bullType.label.copyWith(
                          color: context.appColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
                    const _SendError(),
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

class _SendError extends StatelessWidget {
  const _SendError();

  @override
  Widget build(BuildContext context) {
    final failure = context.select((SendCubit cubit) => cubit.state.failure);
    final buildError = context.select(
      (SendCubit cubit) => cubit.state.hasBuildFailure,
    );
    final confirmError = context.select(
      (SendCubit cubit) => cubit.state.hasConfirmFailure,
    );
    final broadcastError = context.select(
      (SendCubit cubit) => cubit.state.hasBroadcastFailure,
    );
    final frozenBalanceHint = context.select(
      (SendCubit cubit) => cubit.state.frozenBalanceHint,
    );

    if (buildError && failure != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: BullText(
          failure.toTranslated(
            context,
            formattedFrozenBalance: frozenBalanceHint,
          ),
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          color: context.appColors.error,
          maxLines: 5,
          textAlign: .center,
        ),
      );
    }
    if (confirmError) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            BullText(
              context.loc.sendErrorConfirmationFailed,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            if (broadcastError) ...[
              const Gap(8),
              BullText(
                context.loc.sendErrorBroadcastFailed,
                style: context.bullType.body,
                color: context.appColors.error,
                maxLines: 5,
                textAlign: .center,
              ),
            ],
          ],
        ),
      );
    }
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: BullText(
          // Same frozen-coins hint the address and amount steps pass, so a
          // shortfall reads identically wherever it surfaces.
          failure.toTranslated(
            context,
            formattedFrozenBalance: frozenBalanceHint,
          ),
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          color: context.appColors.error,
          maxLines: 5,
          textAlign: .center,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

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
      (SendCubit cubit) => !cubit.state.selectedWallet!.isLiquid,
    );
    final isOnchainSend = context.select(
      (SendCubit cubit) => !cubit.state.isLightning && !cubit.state.isChainSwap,
    );
    final isSweep = context.select((SendCubit cubit) => cubit.state.isSweep);
    final wallet = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet,
    );
    final hasFinalizedTx = context.select(
      (SendCubit cubit) => cubit.state.signedBitcoinTx != null,
    );
    final isSpMode = context.read<SendCubit>().isSpMode;
    final transactionBusy = context.select(
      (SendCubit cubit) =>
          cubit.state.buildingTransaction ||
          cubit.state.signingTransaction ||
          cubit.state.broadcastingTransaction,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if ((isBitcoinWallet || (isOnchainSend && !isSweep)) &&
              !hasFinalizedTx &&
              !isSpMode) ...[
            BullAdvancedOptionsLink(
              label: context.loc.sendAdvancedSettings,
              onPressed: (transactionBusy)
                  ? null
                  : () {
                      BullBottomSheet.show(
                        context: context,
                        child: BlocProvider.value(
                          value: context.read<SendCubit>(),
                          child: const AdvancedOptionsBottomSheet(),
                        ),
                      );
                    },
            ),
            const Gap(12),
          ],
          if (!isSpMode &&
              wallet != null &&
              !wallet.signsLocally &&
              !hasFinalizedTx)
            switch (wallet.signerDevice) {
              final device? when device.isLedger => const SignLedgerButton(),
              final device? when device.isBitBox => const SignBitBoxButton(),
              _ => const ShowPsbtButton(),
            }
          else
            const ConfirmSendButton(),
        ],
      ),
    );
  }
}

class ConfirmSendButton extends StatelessWidget {
  const ConfirmSendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hasFinalizedTx = context.select(
      (SendCubit cubit) => cubit.state.signedBitcoinTx != null,
    );
    final disableSendButton = context.select(
      (SendCubit cubit) => cubit.state.disableConfirmSend,
    );
    final owner = context.findAncestorStateOfType<_SendScreenState>();
    return BullButton.primary(
      label: hasFinalizedTx
          ? context.loc.sendBroadcastTransaction
          : context.loc.sendConfirm,
      onPressed: disableSendButton
          ? null
          : () {
              if (owner != null) {
                owner._confirm();
              } else {
                context.read<SendCubit>().onConfirmTransactionClicked();
              }
            },
    );
  }
}

/// Bitcoin onchain send info section.
///
/// Reads directly from [SendState] — all data (amount, address, fees) is
/// already available after [createTransaction] + [signTransaction].
/// Uses [BullOnchainSendInfoSection] for the layout, same as Liquid.
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
        conversions: state.confirmedRecipientConversions,
        recipientAmountsSat: state.recipientAmountsSat,
        label: state.label,
        formattedAbsoluteFees: state.formattedAbsoluteFees,
        feePriorityTitle: state.selectedFeeOption.title(),
        amountBuilder: (amountSat) => BullAmount.signedSats(
          amountSat,
          interactive: true,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
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
      (SendCubit cubit) => cubit.state.signedBitcoinTx != null,
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
        BullOnchainSendInfoSection(
          labels: context.loc.onchainSendLabels,
          sendWalletLabel: selectedWallet?.displayLabel(context) ?? '',
          addressBuilder: (style, color) =>
              AddressViewer(paymentRequestAddress, style: style, color: color),
          formattedBitcoinAmount: formattedBitcoinAmount,
          formattedFiatEquivalent: formattedFiatEquivalent.isEmpty
              ? ''
              : '~$formattedFiatEquivalent',
          absoluteFees: formattedAbsoluteFees,
          selectedFeeOptionTitle: feeSelectionRowLabel(
            context,
            ui: FeeUi.standard,
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
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          color: context.appColors.secondary,
          textAlign: TextAlign.end,
        ),
        BullAmount.signedSats(
          totalSat,
          interactive: true,
          style: context.bullType.caption,
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
      ui: FeeUi.standard,
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
/// [BullOnchainSendInfoSection].
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
        BullOnchainSendInfoSection(
          labels: context.loc.onchainSendLabels,
          sendWalletLabel: selectedWallet?.displayLabel(context) ?? '',
          addressBuilder: (style, color) =>
              AddressViewer(paymentRequestAddress, style: style, color: color),
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
    final swapReference = context.select(
      (SendCubit cubit) => cubit.state.lightningSwapReference,
    );
    final sendAmountSat = context.select(
      (SendCubit cubit) => cubit.state.lightningPayinAmountSat,
    );
    final receiveAmountSat = context.select(
      (SendCubit cubit) => cubit.state.lightningPayoutAmountSat,
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
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              color: context.appColors.secondary,
              textAlign: .end,
            ),
          ),
          _divider(context),
          if (swapReference != null) ...[
            SendInfoRow(
              title: context.loc.sendSwapId,
              details: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: BullText(
                      swapReference,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      color: context.appColors.secondary,
                      textAlign: .end,
                    ),
                  ),
                  const Gap(4),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: swapReference));
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
          ],
          SendInfoRow(
            title: context.loc.sendTo,
            details: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: AddressViewer(
                    paymentRequestAddress,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                color: context.appColors.secondary,
                textAlign: .end,
              ),
            ),
            _divider(context),
          ],
          if (sendAmountSat != null) ...[
            SendInfoRow(
              title: context.loc.sendSendAmount,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  BullAmount.signedSats(
                    sendAmountSat,
                    interactive: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.secondary,
                  ),
                ],
              ),
            ),
            _divider(context),
          ],
          if (receiveAmountSat != null) ...[
            SendInfoRow(
              title: context.loc.sendReceiveAmount,
              details: Column(
                crossAxisAlignment: .end,
                children: [
                  BullAmount.signedSats(
                    receiveAmountSat,
                    interactive: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.secondary,
                  ),
                ],
              ),
            ),
            _divider(context),
          ],
          if (networkFee != null) ...[
            SendInfoRow(
              title: context.loc.sendSendNetworkFee,
              details: Align(
                alignment: Alignment.centerRight,
                child: BullAmount.signedSats(
                  networkFee,
                  interactive: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.secondary,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
            _divider(context),
          ],
          if (swapFee != null)
            SendInfoRow(
              title: context.loc.sendTransferFee,
              details: Align(
                alignment: Alignment.centerRight,
                child: BullAmount.signedSats(
                  swapFee,
                  interactive: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.secondary,
                  textAlign: TextAlign.end,
                ),
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
            style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
            color: context.appColors.onSurfaceVariant,
          ),
          const Spacer(),
          BullAmount.signedSats(
            amt,
            style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
            color: context.appColors.secondary,
            interactive: false,
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
                    style: context.bullType.label.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    color: context.appColors.onSurfaceVariant,
                  ),
                  const Spacer(),
                  BullAmount.signedSats(
                    total,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.appColors.secondary,
                    interactive: false,
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
                    style: context.bullType.caption,
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
                _feeRow(
                  context,
                  context.loc.sendTransferFee,
                  fees.boltzFee ?? 0,
                ),
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
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
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
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
                BullAmount.signedSats(
                  sendAmount,
                  interactive: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
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
                  BullAmount.signedSats(
                    receiveAmount,
                    interactive: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
                  BullAmount.signedSats(
                    absoluteFees,
                    interactive: true,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
              details: Align(
                alignment: Alignment.centerRight,
                child: BullAmount.signedSats(
                  (orderSwap.order!.payinAmountSat -
                          orderSwap.order!.payoutAmountSat)
                      .toInt(),
                  interactive: true,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.appColors.secondary,
                  textAlign: TextAlign.end,
                ),
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
          child: switch (SendPaymentUi.maybeOf(context)?.arrowImage) {
            final image? => Image(image: image, height: 24, width: 24),
            null => const Icon(Icons.arrow_forward, size: 24),
          },
        ),
        const Gap(16),
        BullText(
          context.loc.sendConfirmSend,
          style: context.bullType.body,
          color: context.appColors.secondary,
        ),
        const Gap(4),
        BullText(
          amountBitcoin,
          style: context.bullType.headline,
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
      (SendCubit cubit) =>
          cubit.state.lightningOrder?.localStatus ==
              OrderSwapLocalStatus.completed ||
          cubit.state.lightningSwap?.status == SwapStatus.completed,
    );
    final isLnSwap = context.select(
      (SendCubit cubit) =>
          cubit.state.lightningOrder != null ||
          cubit.state.lightningSwap != null,
    );
    final isLiquid = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet!.isLiquid,
    );
    final isPayjoin = context.select(
      (SendCubit cubit) => cubit.state.payjoinSender != null,
    );
    final pausedFailure = context.select(
      (SendCubit cubit) => cubit.state.failure is SendPayjoinPausedFailure
          ? cubit.state.failure
          : null,
    );
    final canRetryProposal = context.select(
      (SendCubit cubit) => cubit.state.payjoinSender?.canRetryProposal ?? false,
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
        actions: [
          CloseButton(
            onPressed: () => SendPaymentUi.of(context).openHome(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Align(
          child: Column(
            children: [
              const Gap(192),
              if (pausedFailure == null) const BullLoader.large(),
              if (!isLnSwap && !isPayjoin) ...[
                const Gap(8),
                BullText(
                  context.loc.sendSending,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(8),
                BullText(
                  context.loc.sendBroadcastingTransaction,
                  style: context.bullType.body,
                  maxLines: 4,
                  textAlign: .center,
                ),
              ],
              if (isLnSwap && !isLnPaid) ...[
                const Gap(8),
                BullText(
                  context.loc.sendSending,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(8),
                if (isLiquid)
                  BullText(
                    context.loc.sendSwapInProgressInvoice,
                    style: context.bullType.body,
                    maxLines: 4,
                    textAlign: .center,
                  )
                else
                  BullText(
                    context.loc.sendSwapInProgressBitcoin,
                    style: context.bullType.body,
                    maxLines: 4,
                    textAlign: .center,
                  ),
              ],
              if (isPayjoin) ...[
                const Gap(8),
                BullText(
                  context.loc.sendSending,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(8),
                BullText(
                  pausedFailure?.toTranslated(context) ??
                      context.loc.sendCoordinatingPayjoinTransaction,
                  style: context.bullType.body,
                  maxLines: 10,
                  textAlign: TextAlign.center,
                ),
                if (pausedFailure != null && canRetryProposal) ...[
                  const Gap(16),
                  BullButton.secondary(
                    onPressed: () =>
                        context.read<SendCubit>().retryPayjoinProposal(),
                    label: context.loc.retry,
                  ),
                ],
                if (pausedFailure == null &&
                    showFallbackCountdown &&
                    payjoinExpiresAt != null &&
                    isImminent) ...[
                  const Gap(8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BullText(
                        context.loc.sendPayjoinFallbackCountdown,
                        style: context.bullType.body,
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
    final lightningSwap = context.select(
      (SendCubit cubit) => cubit.state.lightningSwap,
    );
    final isLnInvoicePaid = lightningSwap?.status == SwapStatus.completed;
    final boltzSwap = chainSwap ?? lightningSwap;
    final isBoltzLnSwap = lightningSwap != null;
    final isLnSwap =
        orderSwap != null &&
        (orderSwap.inNetwork == OrderSwapNetwork.lightning ||
            orderSwap.outNetwork == OrderSwapNetwork.lightning);
    final isChainSwap = chainSwap != null || (orderSwap != null && !isLnSwap);
    final isChainSwapCompleted =
        (isChainSwap &&
            orderSwap?.localStatus == OrderSwapLocalStatus.completed) ||
        (chainSwap?.status == SwapStatus.completed &&
            (chainSwap?.receiveTxid?.isNotEmpty ?? false));
    // An order that expired before payin holds no funds — show expiry, not refund.
    final expiredBeforePayin =
        orderSwap != null &&
        orderSwap.localStatus == OrderSwapLocalStatus.expired &&
        orderSwap.localPayinTransactionId == null;
    // Decides whether the View Details button appears.
    final hasDetails =
        walletTransaction != null ||
        orderSwap != null ||
        boltzSwap != null ||
        payjoin != null;
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: _sendFlowTitle(context),
          onBack: () => SendPaymentUi.of(context).openHome(context),
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
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: .center,
                    ),
                    BullText(
                      context.loc.sendSwapExpiredMessage,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: .center,
                    ),
                  ] else if (orderSwap?.localStatus ==
                          OrderSwapLocalStatus.refunded ||
                      boltzSwap?.status == SwapStatus.refunded ||
                      chainSwap?.refundTxid != null ||
                      lightningSwap?.refundTxid != null) ...[
                    BullText(
                      context.loc.sendSwapRefundCompleted,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: .center,
                    ),
                    BullText(
                      context.loc.sendRefundProcessed,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: .center,
                    ),
                  ] else if (orderSwap?.localStatus ==
                          OrderSwapLocalStatus.failed ||
                      orderSwap?.localStatus == OrderSwapLocalStatus.expired ||
                      boltzSwap?.status == SwapStatus.failed ||
                      boltzSwap?.status == SwapStatus.expired ||
                      boltzSwap?.status == SwapStatus.refundable) ...[
                    BullText(
                      context.loc.sendSwapRefundInProgress,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: .center,
                    ),
                    BullText(
                      context.loc.sendSwapFailed,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: .center,
                    ),
                  ] else if ((isLnSwap &&
                          orderSwap.localStatus ==
                              OrderSwapLocalStatus.completed) ||
                      (isBoltzLnSwap && isLnInvoicePaid)) ...[
                    BullText(
                      context.loc.sendInvoicePaid,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else if ((isLnSwap &&
                          !isBitcoin &&
                          orderSwap.localStatus !=
                              OrderSwapLocalStatus.completed) ||
                      (isBoltzLnSwap && !isBitcoin))
                    BullText(
                      context.loc.sendPaymentProcessing,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: .center,
                    )
                  else if ((isLnSwap || isBoltzLnSwap) && isBitcoin)
                    BullText(
                      context.loc.sendPaymentWillTakeTime,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (isChainSwapCompleted)
                    BullText(
                      context.loc.sendSuccessfullySent,
                      style: context.bullType.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: .center,
                    )
                  else if (isChainSwap) ...[
                    BullText(
                      context.loc.sendSwapInitiated,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    BullText(
                      context.loc.sendSwapWillTakeTime,
                      style: context.bullType.caption,
                    ),
                  ] else ...[
                    BullText(
                      context.loc.sendSuccessfullySent,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
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
                        style: context.bullType.body,
                        color: context.appColors.secondary,
                        maxLines: 4,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                  const Gap(8),
                  BullText(
                    amount,
                    style: context.bullType.headline,
                    maxLines: 4,
                    textAlign: .center,
                  ),
                  if (fiatEquivalent.isNotEmpty) ...[
                    const Gap(4),
                    BullText(
                      '~$fiatEquivalent',
                      style: context.bullType.body,
                      color: context.appColors.secondary,
                      maxLines: 4,
                      textAlign: .center,
                    ),
                  ],
                ],
              ),
            ),
            if (orderSwap case final record?
                when record.order?.requiresManualReview == true) ...[
              const Gap(16),
              SendPaymentUi.of(context).orderUnderReview(record),
            ],
            const Spacer(flex: 2),
            if (hasDetails)
              BullButton.secondary(
                label: context.loc.sendViewDetails,
                onPressed: () {
                  if (orderSwap != null) {
                    TransactionsNavigation.openDetails(
                      context,
                      TransactionDetailsTarget.orderSwap(orderSwap.localId),
                      returnHome: true,
                    );
                  } else if (boltzSwap != null) {
                    TransactionsNavigation.openDetails(
                      context,
                      TransactionDetailsTarget.swap(
                        boltzSwap.id,
                        walletId: boltzSwap.walletId,
                      ),
                      returnHome: true,
                    );
                  } else if (walletTransaction != null) {
                    TransactionsNavigation.openDetails(
                      context,
                      TransactionDetailsTarget.wallet(
                        walletTransaction.txId,
                        walletId: walletTransaction.walletId,
                      ),
                      returnHome: true,
                    );
                  } else if (payjoin != null) {
                    // Navigate by the on-chain txid, NOT payjoin.id: a
                    //  sender's id IS the full BIP21 URI (address+amount) and
                    //  would leak into the router location string. By this
                    //  point the session is terminal, so txId (real payjoin)
                    //  or originalTxId (fallback) is always the broadcast tx —
                    //  and landing on the real transaction is better UX than
                    //  the session placeholder.
                    TransactionsNavigation.openDetails(
                      context,
                      TransactionDetailsTarget.wallet(
                        payjoin.txId ?? payjoin.originalTxId,
                        walletId: payjoin.walletId,
                      ),
                      returnHome: true,
                    );
                  }
                },
              ),
            const Gap(32),
          ],
        ),
      ),
    );
  }
}

class ShowPsbtButton extends StatelessWidget {
  const ShowPsbtButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );

    final signerDevice = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.signerDevice,
    );

    return BullButton.primary(
      label: context.loc.sendShowPsbt,
      onPressed: () async {
        // Retain the original wallet and unsigned transaction through handoff.
        final send = context.read<SendCubit>();
        final prepared = send.preparedBitcoin;
        final wallet = switch (send.state.selectedWallet) {
          SendWalletBitcoin(:final wallet) => wallet,
          _ => null,
        };
        final network = wallet?.network;
        if (prepared == null ||
            network is! chains.BitcoinNetwork ||
            prepared.unsignedPsbt != unsignedPsbt) {
          return;
        }
        final result = await SignersNavigation.showPsbt(
          context,
          psbt: prepared.unsignedPsbt,
          signerDevice: signerDevice,
        );
        if (result == PsbtHandoffResult.readyToReadSignedTransaction &&
            context.mounted &&
            identical(send.preparedBitcoin, prepared)) {
          final signed = await SendPsbtHandoff.of(context)(
            context,
            prepared,
            network,
          );
          if (signed == null || !context.mounted) return;
          await send.updateSignedBitcoinTx(signed, prepared: prepared);
        }
      },
    );
  }
}

class SignLedgerButton extends StatelessWidget {
  const SignLedgerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );

    final derivationPath = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.derivationPath,
    );

    final deviceType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.signerDevice,
    );

    final scriptType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.scriptType,
    );

    return BullButton.primary(
      label: context.loc.sendSignWithLedger,
      onPressed: () async {
        final send = context.read<SendCubit>();
        final prepared = send.preparedBitcoin;
        final wallet = send.state.selectedWallet;
        if (prepared == null ||
            prepared.unsignedPsbt != unsignedPsbt ||
            wallet == null ||
            derivationPath == null ||
            scriptType == null) {
          return;
        }

        final result = await SignersNavigation.signLedger(
          context,
          network: wallet.network.env,
          psbt: prepared.unsignedPsbt,
          derivationPath: derivationPath,
          requestedDeviceType: deviceType,
          scriptType: scriptType,
        );

        if (result != null && context.mounted) {
          final accepted = await send.updateSignedBitcoinTx(
            result,
            prepared: prepared,
          );
          if (accepted && context.mounted) {
            BullSnackBar.show(
              context,
              message: context.loc.sendTransactionSignedLedger,
            );
          }
        }
      },
    );
  }
}

class SignBitBoxButton extends StatelessWidget {
  const SignBitBoxButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unsignedPsbt = context.select(
      (SendCubit cubit) => cubit.state.unsignedPsbt,
    );

    final derivationPath = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.derivationPath,
    );

    final deviceType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.signerDevice,
    );

    final scriptType = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.scriptType,
    );

    return BullButton.primary(
      label: context.loc.sendSignWithBitBox,
      onPressed: () async {
        final send = context.read<SendCubit>();
        final prepared = send.preparedBitcoin;
        final wallet = send.state.selectedWallet;
        if (prepared == null ||
            prepared.unsignedPsbt != unsignedPsbt ||
            wallet == null ||
            derivationPath == null ||
            scriptType == null) {
          return;
        }

        final result = await SignersNavigation.signBitBox(
          context,
          network: wallet.network.env,
          psbt: prepared.unsignedPsbt,
          derivationPath: derivationPath,
          requestedDeviceType: deviceType,
          scriptType: scriptType,
        );

        if (result != null && context.mounted) {
          final String finalizedTx;
          try {
            finalizedTx = await _finalizePsbt(result);
          } catch (_) {
            if (!context.mounted) return;
            BullSnackBar.show(
              context,
              message: context.loc.sendErrorConfirmationFailed,
            );
            return;
          }
          if (context.mounted) {
            await send.updateSignedBitcoinTx(finalizedTx, prepared: prepared);
          }
        }
      },
    );
  }

  Future<String> _finalizePsbt(String signedPsbt) async {
    try {
      if (signedPsbt.startsWith('cHN')) {
        final psbt = Psbt.fromBase64(signedPsbt);
        final builder = PsbtBuilder.fromPsbt(psbt);
        return builder.finalizeAll().toHex();
      }
      return signedPsbt;
    } catch (e, st) {
      log.warning('Failed to finalize BitBox signed PSBT', error: e, trace: st);
      Error.throwWithStackTrace(e, st);
    }
  }
}

class _RecipientKitAmount extends StatefulWidget {
  final String amount;
  final BitcoinUnit canonicalUnit;
  final String currencyCode;
  final String defaultCurrencyCode;
  final Map<SupportedCurrency, BitcoinPrice> quotes;
  final FocusNode? focusNode;
  final ValueChanged<BullAmountInputValue> onChanged;

  const _RecipientKitAmount({
    super.key,
    required this.amount,
    required this.canonicalUnit,
    required this.currencyCode,
    required this.defaultCurrencyCode,
    required this.quotes,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  State<_RecipientKitAmount> createState() => _RecipientKitAmountState();
}

class _RecipientKitAmountState extends State<_RecipientKitAmount> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.amount);
  }

  @override
  void didUpdateWidget(_RecipientKitAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.amount) _controller.text = widget.amount;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BullAmountInput(
    key: ValueKey(widget.currencyCode),
    compact: true,
    showControls: false,
    canonicalUnit: widget.canonicalUnit,
    initialCurrencyCode: widget.currencyCode,
    defaultCurrencyCode: widget.defaultCurrencyCode,
    amountController: _controller,
    focusNode: widget.focusNode,
    currencies: [
      for (final currency in SupportedCurrency.values)
        BullAmountCurrency(
          code: currency.code,
          decimals: currency.decimals,
          price: widget.quotes[currency]?.fiatAmount,
          priceAt: widget.quotes[currency]?.fetchedAt,
        ),
    ],
    onEntryChanged: widget.onChanged,
  );
}
