import 'package:exchange/exchange.dart';
import 'package:secrets/secrets.dart' show WalletSigner;

import '../transaction_ui_actions.dart';
import '../transactions_navigation.dart';

import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:transactions/src/domain/transaction_settlement.dart';
import 'package:transactions/src/presentation/blocs/transaction_status/transaction_status_cubit.dart';
import 'package:transactions/src/presentation/transaction_payment_animation.dart';
import 'package:transactions/src/ui/widgets/settlement_sync_poller.dart';
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:primitives/primitives.dart';
import 'package:transactions/src/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:transactions/src/domain/transaction_label_policy.dart';
import 'package:transactions/src/presentation/transaction_failure_l10n.dart';
import 'package:transactions/src/ui/widgets/broadcast_payjoin_original_tx_button.dart';
import 'package:transactions/src/ui/widgets/order_swap_status_description.dart';
import 'package:transactions/src/ui/widgets/retry_swap_button.dart';
import 'package:transactions/src/ui/widgets/swap_progress_indicator.dart';
import 'package:transactions/src/ui/widgets/swap_status_description.dart';
import 'package:transactions/src/ui/widgets/transaction_details_amount.dart';
import 'package:transactions/src/ui/widgets/transaction_details_status_label.dart';
import 'package:transactions/src/ui/widgets/transaction_details_table.dart';
import 'package:label_editor/label_editor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullErrorState,
        BullFadingLinearProgress,
        BullPaymentTransition,
        BullPaymentViewSwitch,
        BullShimmerLine,
        BullSnackBar,
        BullTransactionDetailsPage,
        Gap;
import 'package:go_router/go_router.dart';

/// The transaction, as a payment status ([BullPaymentTransition]) or as its
/// details, switched in place of the old "Transaction details" skip button.
///
/// A transaction with no payment animation shows its details alone. The
/// details open first when the `view=details` query asks for it, when payment
/// animations are turned off, or while an action only the details offer (retry
/// or refund a swap, broadcast a Payjoin original) is pending.
class TransactionDetailsScreen extends StatefulWidget {
  final TransactionUiActions actions;
  final SettlementPoll pollSettlement;

  const TransactionDetailsScreen({
    super.key,
    required this.actions,
    required this.pollSettlement,
  });

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  /// Null until the transaction and the preference are known.
  TransactionDetailsView? _view;

  /// The status view is built once it is first shown, so that a user who keeps
  /// animations off never builds a scene.
  bool _statusBuilt = false;

  @override
  void initState() {
    super.initState();
    // The details cubit may already hold a transaction when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = settlementTargetOf(
        context.read<TransactionDetailsCubit>().state.transaction,
      );
      if (target != null) {
        context.read<TransactionStatusCubit>().observeSettlement(target);
      }
    });
  }

  void _show(TransactionDetailsView view) {
    if (_view == view) return;
    setState(() => _view = view);
  }

  @override
  Widget build(BuildContext context) {
    final query = GoRouterState.of(context).uri.queryParameters;
    final returnHome = query['returnHome'] == 'true';
    final returnToExchange = query['returnToExchange'] == 'true';
    final actions = widget.actions;

    void closeScreen() {
      if (returnToExchange) {
        actions.openExchange(context);
      } else if (returnHome) {
        actions.openWalletHome(context);
      } else if (context.canPop()) {
        context.pop();
      } else {
        actions.openWalletHome(context);
      }
    }

    // A flow that `go`es here leaves this screen alone on the stack, so back
    // had nothing to pop and closed the app. Veto the pop in that case and let
    // closeScreen navigate; when there is a route below, back still pops.
    final canPopBack = context.canPop();

    final detailsState = context.watch<TransactionDetailsCubit>().state;
    final statusState = context.watch<TransactionStatusCubit>().state;
    final animation = transactionPaymentAnimation(
      detailsState,
      context.loc,
      settlement: statusState.settlement,
    );

    final animationsEnabled = statusState.animationsEnabled;
    final loaded =
        detailsState.transaction != null || detailsState.hasLoadError;
    if (_view == null && loaded && animationsEnabled != null) {
      _view =
          TransactionDetailsView.fromQuery(query) ==
                  TransactionDetailsView.details ||
              !animationsEnabled ||
              transactionHasPendingRecovery(detailsState.transaction)
          ? TransactionDetailsView.details
          : TransactionDetailsView.status;
    }
    final view = animation == null
        ? TransactionDetailsView.details
        : (_view ?? TransactionDetailsView.details);
    if (view == TransactionDetailsView.status) _statusBuilt = true;

    final switcher = animation == null
        ? null
        : BullPaymentViewSwitch(
            showingStatus: view == TransactionDetailsView.status,
            statusLabel: context.loc.paymentStatusViewStatus,
            detailsLabel: context.loc.paymentStatusViewDetails,
            semanticsLabel: context.loc.paymentStatusViewsLabel,
            onStatus: () => _show(TransactionDetailsView.status),
            onDetails: () => _show(TransactionDetailsView.details),
          );
    final target = statusState.settlementTarget;

    return BlocListener<TransactionDetailsCubit, TransactionDetailsState>(
      listenWhen: (previous, current) =>
          previous.transaction != current.transaction,
      listener: (context, state) => context
          .read<TransactionStatusCubit>()
          .observeSettlement(settlementTargetOf(state.transaction)),
      // The single route-level back handler for both views.
      child: PopScope(
        canPop: canPopBack,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) closeScreen();
        },
        child: IndexedStack(
          sizing: StackFit.expand,
          index: view == TransactionDetailsView.status ? 0 : 1,
          children: [
            // A hidden view must not tick: its scene stops animating.
            TickerMode(
              enabled: view == TransactionDetailsView.status,
              child: animation == null || !_statusBuilt
                  ? const SizedBox.shrink()
                  : SettlementSyncPoller(
                      walletId: target?.walletId,
                      active:
                          view == TransactionDetailsView.status &&
                          statusState.settlementPending,
                      isLiquid: target?.isLiquid ?? false,
                      poll: widget.pollSettlement,
                      child: BullPaymentTransition(
                        network: animation.network,
                        direction: animation.direction,
                        phase: animation.phase,
                        progress: animation.progress,
                        status: animation.status,
                        statusTag: animation.status,
                        bottom: switcher,
                        onBack: closeScreen,
                        onDone: () {},
                      ),
                    ),
            ),
            TickerMode(
              enabled: view == TransactionDetailsView.details,
              child: _details(
                context,
                closeScreen: closeScreen,
                canPopBack: canPopBack,
                switcher: switcher,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(
    BuildContext context, {
    required VoidCallback closeScreen,
    required bool canPopBack,
    required Widget? switcher,
  }) {
    final actions = widget.actions;
    final isLoading = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.isLoading,
    );
    final hasLoadError = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.hasLoadError,
    );
    final tx = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.transaction,
    );
    final wallet = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.wallet,
    );
    final isBroadcastingPayjoinOriginalTx = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.isBroadcastingPayjoinOriginalTx,
    );
    final retryingSwap = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.retryingSwap,
    );

    final isOutgoing = tx?.isOutgoing;
    final isIncoming = tx?.isIncoming;
    final isOngoingSwap = tx?.isOngoingSwap;
    final order = tx?.order;
    final walletTransaction = tx?.walletTransaction;
    final payjoin = tx?.payjoin;
    final swap = tx?.swap;
    final orderSwap = tx?.orderSwap;
    final isChainSwap = tx?.isChainSwap ?? false;

    return BullTransactionDetailsPage(
      title: isOngoingSwap == true
          ? (isChainSwap
                ? context.loc.transactionDetailTransferProgress
                : context.loc.transactionDetailSwapProgress)
          : context.loc.transactionDetailTitle,
      isLoading: isLoading,
      isIncoming: isIncoming ?? false,
      isSwap: isChainSwap,
      canPopBack: canPopBack,
      handlesBack: false,
      onClose: closeScreen,
      onRefresh: () => context.read<TransactionDetailsCubit>().refresh(),
      errorContent: hasLoadError ? const _LoadErrorContent() : null,
      appBarBottom: PreferredSize(
        preferredSize: const Size.fromHeight(3.0),
        child: BullFadingLinearProgress(
          trigger: isBroadcastingPayjoinOriginalTx || retryingSwap,
          backgroundColor: context.bull.onPrimary,
          foregroundColor: context.bull.primary,
        ),
      ),
      status: const TransactionDetailsStatusLabel(),
      afterStatus: [
        if (isOngoingSwap == true && swap != null) ...[
          const Gap(8),
          SwapProgressIndicator(swap: swap),
        ],
      ],
      amount: const TransactionDetailsAmount(),
      beforeDetails: [
        if (isOngoingSwap == true && swap != null) ...[
          SwapStatusDescription(swap: swap),
          if (swap.requiresAction) ...[
            const Gap(16),
            RetrySwapButton(swap: swap),
          ],
          const Gap(16),
        ],
        if (isOngoingSwap == true && orderSwap != null) ...[
          OrderSwapStatusDescription(
            orderSwap: orderSwap,
            orderSwapUnderReview: actions.orderSwapUnderReview,
          ),
          const Gap(16),
        ],
        if (order is BuyOrder &&
            order.bitcoinAddress != null &&
            order.sentAt == null) ...[
          actions.accelerateOrder(context, order.orderId),
          const Gap(16),
        ],
      ],
      details: TransactionDetailsTable(actions: actions),
      afterDetails: [
        if (order is FiatPaymentOrder &&
            order.payoutMethod == OrderPaymentMethod.sinpe &&
            order.payoutCurrency == 'CRC') ...[
          const Gap(16),
          BullButton.secondary(
            label: context.loc.payViewReceipt,
            onPressed: () {
              actions.showReceipt(context, order);
            },
          ),
        ],
      ],
      footer: [
        if (payjoin != null) BroadcastPayjoinOriginalTxButton(payjoin: payjoin),
        if (isLoading)
          const BullShimmerLine(height: 40)
        else
          BullButton.secondary(
            label: context.loc.transactionDetailAddNote,
            onPressed:
                (walletTransaction == null ||
                    !TransactionLabelPolicy.canAdd(
                      walletTransaction.labels.length,
                    ))
                ? null
                : () async {
                    final cubit = context.read<TransactionDetailsCubit>();
                    final saved = await LabelEditor.label(
                      context,
                      title: context.loc.transactionNoteAddTitle,
                      suggestionsFuture: cubit.fetchDistinctLabels(),
                      hint: context.loc.transactionNoteHint,
                    );
                    if (saved == null || !context.mounted) return;
                    final result = await cubit.saveTransactionLabel(saved);
                    if (result case Err(:final failure)) {
                      if (context.mounted) {
                        BullSnackBar.show(
                          context,
                          message: failure.toTranslated(context),
                        );
                      }
                    }
                  },
          ),
        const Gap(16),
        if (isOutgoing == true &&
            walletTransaction != null &&
            !walletTransaction.isConfirmed &&
            walletTransaction.isRbf &&
            walletTransaction.isBitcoin &&
            wallet?.signer == WalletSigner.local &&
            tx?.txId != null &&
            tx?.isSwap != true)
          BullButton.secondary(
            label: context.loc.transactionDetailAccelerate,
            onPressed: () {
              actions.accelerateWalletTransaction(context, walletTransaction);
            },
          ),
        ?switcher,
      ],
    );
  }
}

class _LoadErrorContent extends StatelessWidget {
  const _LoadErrorContent();

  @override
  Widget build(BuildContext context) {
    final failure = context.select(
      (TransactionDetailsCubit cubit) => cubit.state.loadFailure,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: BullErrorState(
          message:
              failure?.toTranslated(context) ??
              context.loc.transactionDetailLoadError,
          retryLabel: context.loc.retry,
          onRetry: () => context.read<TransactionDetailsCubit>().refresh(),
        ),
      ),
    );
  }
}
