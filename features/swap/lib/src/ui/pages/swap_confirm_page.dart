import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:fees/fees.dart';
import 'package:swap_feature/src/ui/widgets/swap_confirmation_details.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/presentation/swap_failure_l10n.dart';
import 'package:swap_feature/src/presentation/transfer_confirm_error.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:swaps/swaps.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swap_feature/src/ui/swap_router.dart';
import 'package:transactions/payment_status.dart';
import 'package:transactions/routes.dart';
import 'package:transactions/transactions.dart'
    show SettlementPoll, SettlementSyncPoller;
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullConfirmationHeader,
        BullFadingLinearProgress,
        BullOnchainSendInfoSection,
        BullPaymentNetwork,
        BullPaymentPhase,
        BullPaymentTransition,
        BullText,
        BullTypographyX,
        BullUiLocalizations,
        Gap;

class SwapConfirmPage extends StatefulWidget {
  const SwapConfirmPage({super.key, this.poll});

  /// Refreshes the receiving wallet; no polling when absent.
  final SettlementPoll? poll;

  @override
  State<SwapConfirmPage> createState() => _SwapConfirmPageState();
}

class _SwapConfirmPageState extends State<SwapConfirmPage> {
  String? _attemptSwapId;
  String? _attemptOrderId;
  BullPaymentNetwork? _network;
  bool _showTransition = false;
  bool _statusOpen = false;
  bool _confirmArmed = false;
  bool _awaitingDetails = false;

  void _confirm(TransferState state) {
    // The path (animation or details) depends on the preference.
    if (_confirmArmed ||
        state.isConfirming ||
        state.showPaymentAnimations == null) {
      return;
    }
    _confirmArmed = true;
    final swap = state.swap;
    if (!state.isSameChainTransfer &&
        swap != null &&
        state.showPaymentAnimations == false) {
      // Without the transition the details open once the lockup is broadcast.
      _awaitingDetails = true;
    } else if (!state.isSameChainTransfer && swap != null) {
      setState(() {
        _attemptSwapId = swap.id;
        _attemptOrderId = state.orderSwap?.localId;
        _network = _attemptOrderId == null
            ? BullPaymentNetwork.boltz
            : swap.type == SwapType.bitcoinToLiquid
            ? BullPaymentNetwork.liquid
            : BullPaymentNetwork.bitcoin;
        _showTransition = true;
      });
    }
    context.read<TransferBloc>().add(const TransferEvent.confirmed());
  }

  /// With payment animations off, opens the details once, as soon as the
  /// funding broadcast gives the transfer a durable target.
  void _openDetailsWithoutTransition(TransferState state) {
    if (!_awaitingDetails || state.txId.isEmpty) return;
    final swap = state.swap;
    final orderId = state.orderSwap?.localId ?? _attemptOrderId;
    final TransactionDetailsTarget? target = orderId != null
        ? TransactionDetailsTarget.orderSwap(orderId)
        : swap == null
        ? null
        : TransactionDetailsTarget.swap(swap.id, walletId: swap.walletId);
    if (target == null) return;
    _awaitingDetails = false;
    TransactionsNavigation.goToDetails(
      context,
      target,
      returnHome: true,
      view: TransactionDetailsView.details,
    );
  }

  Future<void> _openStatus() async {
    if (_statusOpen) return;
    setState(() {
      _showTransition = false;
      _statusOpen = true;
    });
    final bloc = context.read<TransferBloc>();
    final state = bloc.state;
    final orderId = _attemptOrderId ?? state.orderSwap?.localId;
    try {
      if (state.txId.isNotEmpty) {
        if (orderId != null) {
          TransactionsNavigation.goToDetails(
            context,
            TransactionDetailsTarget.orderSwap(orderId),
            returnHome: true,
            view: TransactionDetailsView.details,
          );
        } else {
          context.goNamed(TransferRoute.inProgressSwap.name, extra: bloc);
        }
      } else if (orderId != null) {
        await TransactionsNavigation.openDetails(
          context,
          TransactionDetailsTarget.orderSwap(orderId),
          returnHome: true,
          view: TransactionDetailsView.details,
        );
      } else {
        await context.pushNamed<void>(
          TransferRoute.inProgressSwap.name,
          extra: bloc,
        );
      }
    } finally {
      if (mounted) setState(() => _statusOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromWallet = context.select(
      (TransferBloc bloc) => bloc.state.fromWallet,
    );
    final toWallet = context.select((TransferBloc bloc) => bloc.state.toWallet);
    final swap = context.select((TransferBloc bloc) => bloc.state.swap);
    final formattedInputAmount = context.select(
      (TransferBloc bloc) => bloc.state.formattedInputAmount,
    );
    final formattedConfirmedAmountBitcoin = formattedInputAmount;

    final swapFailure = context.select(
      (TransferBloc bloc) => bloc.state.swapFailure,
    );
    final buildTransactionException = context.select(
      (TransferBloc bloc) => bloc.state.buildTransactionException,
    );
    final absoluteFeesFormatted = context.select(
      (TransferBloc bloc) => bloc.state.absoluteFeesFormatted,
    );
    final isConfirming = context.select(
      (TransferBloc bloc) => bloc.state.isConfirming,
    );
    final sendToExternal = context.select(
      (TransferBloc bloc) => bloc.state.sendToExternal,
    );
    final transferReady = context.select(
      (TransferBloc bloc) =>
          bloc.state.isSameChainTransfer || bloc.state.swap != null,
    );
    final state = context.watch<TransferBloc>().state;
    final canRetryRejectedPayin =
        context.read<TransferBloc>().canRetryRejectedOrderPayin &&
        state.txId.isEmpty &&
        state.swap?.status == SwapStatus.pending &&
        !(state.swap?.sendTxid?.isNotEmpty ?? false) &&
        state.swap?.refundTxid == null;
    final attemptId = _attemptSwapId;
    final currentSwap = state.swap;
    final sameAttempt =
        attemptId != null &&
        currentSwap?.id == attemptId &&
        (_attemptOrderId == null ||
            state.orderSwap?.localId == _attemptOrderId);
    final phase = attemptId == null
        ? BullPaymentPhase.sending
        : swapTransitionPhase(
            swapId: attemptId,
            orderId: _attemptOrderId,
            swap: currentSwap,
            order: state.orderSwap,
            fundingTxId: state.txId,
            receiveTransaction: state.receiveTransaction,
          );
    final copy = context.swapCopyForLocale;
    final observable = swapReceiveObservable(currentSwap);
    final progress = swapTransitionProgress(
      swapId: attemptId ?? '',
      orderId: _attemptOrderId,
      swap: currentSwap,
      order: state.orderSwap,
      fundingTxId: state.txId,
      receiveTransaction: state.receiveTransaction,
      steps: _attemptOrderId == null
          ? [
              copy.paymentStepSendingLockup,
              copy.paymentStepLockupSent,
              copy.paymentStepClaimable,
              copy.paymentStepClaimBroadcast,
              if (observable) copy.paymentStepConfirmed,
            ]
          : [
              copy.paymentStepSendingPayin,
              copy.paymentStepPayinBroadcast,
              copy.paymentStepPayoutInProgress,
              if (observable) ...[
                copy.paymentStepPayoutBroadcast,
                copy.paymentStepConfirmed,
              ] else
                copy.paymentStepCompleted,
            ],
    );
    final completed = phase == BullPaymentPhase.success;
    final failed = phase == BullPaymentPhase.failed;
    final provisionalFailure =
        sameAttempt &&
        currentSwap != null &&
        (currentSwap.status == SwapStatus.failed ||
            currentSwap.status == SwapStatus.expired) &&
        phase == BullPaymentPhase.sending;
    final requiresStatus =
        !state.isSameChainTransfer &&
        (state.txId.isNotEmpty ||
            (sameAttempt &&
                currentSwap != null &&
                currentSwap.status != SwapStatus.pending) ||
            (state.orderSwap?.hasFundsMoved ?? false) ||
            (currentSwap?.pendingLockupTx?.isNotEmpty ?? false) ||
            state.swapFailure is SwapLockupPendingFailure ||
            (state.orderSwap?.localStatus ==
                    OrderSwapLocalStatus.broadcastUnknown &&
                !canRetryRejectedPayin));
    final confirmPage = BlocListener<TransferBloc, TransferState>(
      listenWhen: (previous, current) =>
          previous.isConfirming && !current.isConfirming,
      listener: (context, state) {
        setState(() {
          _confirmArmed = false;
          if (state.txId.isEmpty) {
            _showTransition = false;
            _awaitingDetails = false;
          }
        });
        _openDetailsWithoutTransition(state);
      },
      child: PopScope<Object?>(
        canPop: !_showTransition && !requiresStatus,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_showTransition) {
            setState(() => _showTransition = false);
          } else if (requiresStatus) {
            _openStatus();
          }
        },
        child: Stack(
          children: [
            ExcludeSemantics(
              excluding: _showTransition,
              child: ExcludeFocus(
                excluding: _showTransition,
                child: IgnorePointer(
                  ignoring: _showTransition,
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(
                        context.swapCopyForLocale.swapConfirmTransferTitle,
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(3),
                        child: BullFadingLinearProgress(
                          height: 3,
                          trigger: isConfirming,
                          backgroundColor: context.appColors.onPrimary,
                          foregroundColor: context.appColors.primary,
                        ),
                      ),
                    ),
                    body: SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: .stretch,
                            children: [
                              const Gap(8),
                              BullConfirmationHeader(
                                amount: formattedConfirmedAmountBitcoin,
                                title: sendToExternal
                                    ? context
                                          .swapCopyForLocale
                                          .coreScreensExternalTransfer
                                    : context
                                          .swapCopyForLocale
                                          .coreScreensInternalTransfer,
                                icon: Image.asset(
                                  'assets/icons/swap.png',
                                  height: 24,
                                  width: 24,
                                ),
                              ),
                              if (context.select(
                                    (TransferBloc bloc) =>
                                        bloc.state.confirmedConversion,
                                  )
                                  case final conversion?)
                                Text(
                                  context.swapCopyForLocale.amountEnteredAtRate(
                                    conversion.enteredText,
                                    conversion.currencyCode,
                                    MaterialLocalizations.of(context)
                                        .formatTimeOfDay(
                                          TimeOfDay.fromDateTime(
                                            conversion.quotedAt.toLocal(),
                                          ),
                                          alwaysUse24HourFormat: true,
                                        ),
                                  ),
                                  style: context.bullType.label.copyWith(
                                    color: context.appColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              const Gap(40),
                              BlocSelector<TransferBloc, TransferState, bool>(
                                selector: (state) => state.isSameChainTransfer,
                                builder: (context, isSameChainTransfer) {
                                  if (fromWallet == null) {
                                    return const SizedBox.shrink();
                                  }
                                  if (isSameChainTransfer) {
                                    final formattedFiatEquivalent = context.select((
                                      TransferBloc bloc,
                                    ) {
                                      final amount = bloc.state.inputAmountSat;
                                      final rate = bloc.state.exchangeRate;
                                      final currency =
                                          bloc.state.fiatCurrencyCode ?? 'CAD';
                                      if (rate == null) return '';
                                      final fiatAmount =
                                          amount * rate / 100000000;
                                      return '${fiatAmount.toStringAsFixed(2)} $currency';
                                    });
                                    final selectedFeeOption = context.select(
                                      (TransferBloc bloc) =>
                                          bloc.state.selectedFeeOption,
                                    );
                                    final customFee = context.select(
                                      (TransferBloc bloc) =>
                                          bloc.state.customFee,
                                    );
                                    final selectedFeeOptionTitle =
                                        feeSelectionRowLabel(
                                          context,
                                          ui: FeeUi.standard,
                                          selection: selectedFeeOption,
                                          customFee: customFee,
                                          fastestLabel: context
                                              .swapCopyForLocale
                                              .sendFastFee,
                                        );
                                    final toWalletLabel = context.select(
                                      (TransferBloc bloc) =>
                                          bloc.state.toWallet?.swapWalletLabel(
                                            context,
                                          ) ??
                                          '',
                                    );
                                    return BullOnchainSendInfoSection(
                                      labels: context
                                          .swapCopyForLocale
                                          .onchainSendLabels,
                                      sendWalletLabel: fromWallet
                                          .swapWalletLabel(context),
                                      addressBuilder: (style, color) =>
                                          AddressViewer(
                                            toWalletLabel,
                                            style: style,
                                            color: color,
                                          ),
                                      formattedBitcoinAmount:
                                          formattedConfirmedAmountBitcoin,
                                      formattedFiatEquivalent:
                                          formattedFiatEquivalent,
                                      absoluteFees: absoluteFeesFormatted,
                                      selectedFeeOptionTitle:
                                          selectedFeeOptionTitle,
                                      onFeePriorityTap: () {
                                        final bloc = context
                                            .read<TransferBloc>();
                                        BullBottomSheet.show(
                                          context: context,
                                          child: FeeOptionsModal(
                                            ui: FeeUi.standard,
                                            viewState: bloc,
                                            actions: bloc,
                                            defaultAbsoluteCustomFee: true,
                                            customFeeColors:
                                                FeeModalCustomFeeColors(
                                                  tile: context
                                                      .appColors
                                                      .onSecondary,
                                                  shadow: context
                                                      .appColors
                                                      .secondary,
                                                  unselectedIcon:
                                                      context.appColors.surface,
                                                ),
                                          ),
                                        ).then((selected) {
                                          if (!context.mounted) return;
                                          final bloc = context
                                              .read<TransferBloc>();
                                          if (selected != null) {
                                            // Preset picked — commit it. The
                                            // event handler clears any in-flight
                                            // arm from custom typing.
                                            try {
                                              final fee =
                                                  FeeSelectionName.fromString(
                                                    selected,
                                                  );
                                              bloc.add(
                                                TransferEvent.feeOptionSelected(
                                                  fee,
                                                ),
                                              );
                                            } catch (e) {
                                              // Ignore invalid fee selection
                                            }
                                          } else {
                                            // User dismissed the modal (tap
                                            // outside, back, swipe). Finalize the
                                            // typed custom rate if any. Replaces
                                            // the old "Confirm Custom Fee" button.
                                            bloc.add(
                                              const TransferEvent.customFeeFinalized(),
                                            );
                                          }
                                        });
                                      },
                                    );
                                  } else {
                                    if (swap == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final receiveWalletLabel = sendToExternal
                                        ? null
                                        : toWallet?.swapWalletLabel(context);
                                    return SwapConfirmationDetails(
                                      sendWalletLabel: fromWallet
                                          .swapWalletLabel(context),
                                      receiveWalletLabel: receiveWalletLabel,
                                      formattedBitcoinAmount:
                                          formattedConfirmedAmountBitcoin,
                                      swap: swap,
                                    );
                                  }
                                },
                              ),
                              const Gap(24),
                              _SwapConfirmationError(
                                errorMessage: transferConfirmErrorMessage(
                                  buildTransactionException:
                                      buildTransactionException,
                                  swapFailureMessage: swapFailure?.toTranslated(
                                    context,
                                  ),
                                  buildFailureMessage: context
                                      .swapCopyForLocale
                                      .sendErrorBuildFailed,
                                  selectedCoinsUnavailableMessage: context
                                      .swapCopyForLocale
                                      .sendErrorSelectedCoinsUnavailable,
                                  selectedCoinsInsufficientMessage: context
                                      .swapCopyForLocale
                                      .sendErrorSelectedCoinsInsufficient,
                                  transactionChangedMessage: context
                                      .swapCopyForLocale
                                      .sendErrorTransactionChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    bottomNavigationBar: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BullButton.primary(
                              label: requiresStatus
                                  ? BullUiLocalizations.of(context)
                                        .paymentViewStatus
                                  : canRetryRejectedPayin
                                  ? context.swapCopyForLocale.retry
                                  : context
                                        .swapCopyForLocale
                                        .coreScreensConfirmButton,
                              onPressed: requiresStatus
                                  ? _openStatus
                                  : _confirmArmed ||
                                        isConfirming ||
                                        fromWallet == null ||
                                        state.showPaymentAnimations == null ||
                                        !transferReady
                                  ? null
                                  : () => _confirm(state),
                            ),
                            if (attemptId != null &&
                                !requiresStatus &&
                                swapFailure != null) ...[
                              const Gap(8),
                              BullButton.secondary(
                                label: context
                                    .swapCopyForLocale
                                    .swapContinueButton,
                                onPressed: _openStatus,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showTransition)
              if (_network case final network?)
                Positioned.fill(
                  child: BullPaymentTransition(
                    network: network,
                    phase: phase,
                    descriptor: _attemptOrderId != null
                        ? context.swapCopyForLocale.paymentExchangeDescriptor
                        : null,
                    statusTag: completed
                        ? context.swapCopyForLocale.swapTransferCompletedTitle
                        : sameAttempt &&
                              (currentSwap?.refundTxid != null ||
                                  currentSwap?.status == SwapStatus.refunded)
                        ? context.swapCopyForLocale.swapTransferRefundedTitle
                        : sameAttempt &&
                              currentSwap?.status == SwapStatus.refundable
                        ? context
                              .swapCopyForLocale
                              .swapTransferRefundInProgressTitle
                        : sameAttempt &&
                              currentSwap?.status == SwapStatus.expired
                        ? context.swapCopyForLocale.transactionStatusSwapExpired
                        : failed
                        ? context.swapCopyForLocale.transactionStatusSwapFailed
                        : sameAttempt && progress.completed > 0
                        ? progress.steps[progress.completed]
                        : context.swapCopyForLocale.swapTransferPendingTitle,
                    progress: progress,
                    status: completed
                        ? context.swapCopyForLocale.swapTransferCompletedTitle
                        : sameAttempt &&
                              (currentSwap?.refundTxid != null ||
                                  currentSwap?.status == SwapStatus.refunded)
                        ? context.swapCopyForLocale.swapTransferRefundedTitle
                        : sameAttempt &&
                              currentSwap?.status == SwapStatus.refundable
                        ? context
                              .swapCopyForLocale
                              .swapTransferRefundInProgressTitle
                        : provisionalFailure
                        ? context.swapCopyForLocale.swapTransferPendingTitle
                        : sameAttempt &&
                              currentSwap?.status == SwapStatus.expired
                        ? context.swapCopyForLocale.transactionStatusSwapExpired
                        : failed
                        ? context.swapCopyForLocale.transactionStatusSwapFailed
                        : context.swapCopyForLocale.swapTransferPendingTitle,
                    skipLabel: BullUiLocalizations.of(context)
                        .paymentViewStatus,
                    onSkip: _openStatus,
                    onDone: completed ? () {} : _openStatus,
                    onBackdropTap: () =>
                        setState(() => _showTransition = false),
                  ),
                ),
          ],
        ),
      ),
    );
    final page = BlocListener<TransferBloc, TransferState>(
      listenWhen: (previous, current) =>
          previous.txId.isEmpty && current.txId.isNotEmpty,
      listener: (_, state) => _openDetailsWithoutTransition(state),
      child: confirmPage,
    );
    final poll = widget.poll;
    if (poll == null) return page;
    final receiveTxId = currentSwap?.receiveTxid;
    final receiveTransaction = state.receiveTransaction;
    return SettlementSyncPoller(
      walletId: currentSwap?.receiveWalletId,
      active:
          _showTransition &&
          (receiveTxId?.isNotEmpty ?? false) &&
          !(receiveTransaction?.txId == receiveTxId &&
              receiveTransaction?.isConfirmed == true),
      isLiquid: currentSwap?.type == SwapType.bitcoinToLiquid,
      poll: poll,
      child: page,
    );
  }
}

class _SwapConfirmationError extends StatelessWidget {
  const _SwapConfirmationError({required this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage case final message?) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            BullText(
              context.swapCopyForLocale.sendErrorBuildFailed,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            const Gap(8),
            BullText(
              message,
              style: context.bullType.body,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: .center,
            ),
            const Gap(8),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
