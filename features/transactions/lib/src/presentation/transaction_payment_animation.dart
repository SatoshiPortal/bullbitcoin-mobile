import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinReceiverSession, PayjoinSession, PayjoinStatus;
import 'package:bull_ui/bull_ui.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart' show BuyOrder;
import 'package:swaps/order_swaps.dart' show OrderSwapNetwork;
import 'package:swaps/swaps.dart';
import 'package:transactions/payment_status.dart';
import 'package:transactions/src/domain/entities/transaction.dart';
import 'package:transactions/src/domain/entities/wallet_transaction.dart';
import 'package:transactions/src/domain/transaction_settlement.dart';
import 'package:transactions/src/presentation/blocs/transaction_details/transaction_details_cubit.dart';

import '../../generated/l10n/transactions_localizations.dart';

/// What the payment status view plays for one transaction.
final class TransactionPaymentAnimation {
  final BullPaymentNetwork network;
  final BullPaymentDirection direction;
  final BullPaymentPhase phase;
  final BullPaymentProgress progress;

  /// Headline: the real status in words.
  final String status;

  const TransactionPaymentAnimation({
    required this.network,
    required this.direction,
    required this.phase,
    required this.progress,
    required this.status,
  });
}

/// Maps the transaction on screen to its payment animation, or null when it has
/// none (Ark movements, fiat-only orders, legacy items, a transaction still
/// loading): the screen then shows the details alone.
///
/// A transaction can hold several records; the first that applies wins: order
/// swap, Boltz swap, Payjoin, Buy order, wallet transaction. [settlement] is
/// the observed settlement transaction (see [settlementTargetOf]); only a
/// confirmed observation of that exact transaction completes the last status.
/// A Buy order is shown from its snapshot alone, never a fabricated watch.
TransactionPaymentAnimation? transactionPaymentAnimation(
  TransactionDetailsState state,
  TransactionsLocalizations labels, {
  WalletTransaction? settlement,
}) {
  final transaction = state.transaction;
  if (transaction == null) return null;
  final target = settlementTargetOf(transaction);
  // Only an observation of the very settlement transaction counts.
  final observed =
      target != null &&
          settlement != null &&
          settlement.walletId == target.walletId &&
          settlement.txId == target.txId
      ? settlement
      : null;
  final confirmed = observed?.isConfirmed ?? false;
  final orderSwap = transaction.orderSwap;
  if (orderSwap != null) {
    return _orderSwap(transaction, labels, confirmed: confirmed);
  }
  final swap = transaction.swap;
  if (swap != null) {
    return _boltzSwap(swap, labels, confirmed: confirmed, observed: observed);
  }
  final payjoin = transaction.payjoin;
  if (payjoin != null) {
    return _payjoin(transaction, payjoin, labels, confirmed: confirmed);
  }
  final order = transaction.order;
  if (order is BuyOrder) return _buy(order, labels);
  final walletTransaction = transaction.walletTransaction;
  if (walletTransaction != null) return _wallet(walletTransaction, labels);
  return null;
}

/// Whether the transaction holds an action the user can still take that the
/// Details view owns: retrying or refunding a swap, broadcasting the original
/// Payjoin transaction. The details are shown first so it stays reachable.
bool transactionHasPendingRecovery(Transaction? transaction) {
  if (transaction == null) return false;
  if (transaction.swap?.requiresAction ?? false) return true;
  return transaction.payjoin?.canManuallyBroadcastOriginalAt(clock.now()) ??
      false;
}

String _current(BullPaymentProgress progress) =>
    progress.steps[progress.completed.clamp(0, progress.steps.length - 1)];

/// The status in words. [broadcastWording] names a broadcast status as waiting
/// in the mempool, which only fits a plain transaction.
String _status(
  BullPaymentProgress progress,
  BullPaymentPhase phase,
  TransactionsLocalizations labels, {
  bool broadcastWording = false,
}) {
  if (phase == BullPaymentPhase.success) return progress.steps.last;
  if (progress.refund == BullPaymentRefund.done) {
    return labels.paymentStatusRefunded;
  }
  if (progress.refund == BullPaymentRefund.available) {
    return labels.paymentStatusRefundInProgress;
  }
  if (progress.failedAt != null || phase == BullPaymentPhase.failed) {
    return labels.paymentStatusFailed;
  }
  if (broadcastWording &&
      progress.currentState == BullPaymentStepState.broadcast) {
    return labels.paymentStatusPendingMempool;
  }
  return _current(progress);
}

BullPaymentNetwork? _chainNetwork(bool bitcoin, bool liquid) => bitcoin
    ? BullPaymentNetwork.bitcoin
    : liquid
    ? BullPaymentNetwork.liquid
    : null;

TransactionPaymentAnimation? _wallet(
  WalletTransaction transaction,
  TransactionsLocalizations labels,
) {
  final network = _chainNetwork(transaction.isBitcoin, transaction.isLiquid);
  if (network == null) return null;
  final confirmed = transaction.isConfirmed;
  if (transaction.isIncoming) {
    final steps = [labels.paymentStatusDetected, labels.paymentStatusConfirmed];
    final progress = receiveOnchainProgress(steps: steps, confirmed: confirmed);
    final phase = receiveOnchainPhase(confirmed: confirmed);
    return TransactionPaymentAnimation(
      network: network,
      direction: BullPaymentDirection.incoming,
      phase: phase,
      progress: progress,
      status: _status(progress, phase, labels, broadcastWording: true),
    );
  }
  final steps = [
    labels.paymentStatusSigning,
    labels.paymentStatusBroadcasted,
    labels.paymentStatusConfirmed,
  ];
  final progress = directPaymentProgress(
    steps: steps,
    broadcast: true,
    failed: false,
  );
  final phase = confirmed ? BullPaymentPhase.success : BullPaymentPhase.sending;
  return TransactionPaymentAnimation(
    network: network,
    direction: BullPaymentDirection.outgoing,
    phase: phase,
    progress: progress,
    status: _status(progress, phase, labels, broadcastWording: true),
  );
}

TransactionPaymentAnimation? _orderSwap(
  Transaction transaction,
  TransactionsLocalizations labels, {
  required bool confirmed,
}) {
  final record = transaction.orderSwap;
  // A swap paid from outside the app starts with a payin this app never sees.
  if (record == null || record.sourceWalletId == null) return null;
  final observable = orderSwapPayoutObservable(record);
  final steps = [
    labels.paymentStatusSendingPayin,
    labels.paymentStatusPayinBroadcast,
    labels.paymentStatusPayoutInProgress,
    if (observable) ...[
      labels.paymentStatusPayoutBroadcast,
      labels.paymentStatusConfirmed,
    ] else
      labels.paymentStatusCompleted,
  ];
  final progress = orderSwapDetailsProgress(
    steps: steps,
    record: record,
    confirmed: confirmed,
  );
  final phase = orderSwapDetailsPhase(record: record, confirmed: confirmed);
  return TransactionPaymentAnimation(
    network: switch (record.outNetwork) {
      OrderSwapNetwork.bitcoin => BullPaymentNetwork.bitcoin,
      OrderSwapNetwork.lightning => BullPaymentNetwork.lightning,
      OrderSwapNetwork.liquid => BullPaymentNetwork.liquid,
    },
    direction: BullPaymentDirection.outgoing,
    phase: phase,
    progress: progress,
    status: _status(progress, phase, labels),
  );
}

TransactionPaymentAnimation _boltzSwap(
  Swap swap,
  TransactionsLocalizations labels, {
  required bool confirmed,
  required WalletTransaction? observed,
}) {
  switch (swap) {
    case LnReceiveSwap():
      final direct = swap.wasDirectPayment;
      final hasReceiveTxid = swap.receiveTxid?.isNotEmpty ?? false;
      final steps = [
        direct
            ? labels.paymentStatusPaymentDetected
            : labels.paymentStatusBoltzLockup,
        if (!direct) labels.paymentStatusClaimBroadcast,
        labels.paymentStatusConfirmed,
      ];
      final progress = receiveLightningProgress(
        steps: steps,
        status: swap.status,
        wasDirectPayment: direct,
        hasReceiveTxid: hasReceiveTxid,
        confirmed: confirmed,
      );
      final phase = receiveLightningPhase(
        status: swap.status,
        wasDirectPayment: direct,
        hasReceiveTxid: hasReceiveTxid,
        confirmed: confirmed,
      );
      return TransactionPaymentAnimation(
        network: BullPaymentNetwork.lightning,
        direction: BullPaymentDirection.incoming,
        phase: phase,
        progress: progress,
        status: _status(progress, phase, labels),
      );
    case LnSendSwap():
      final steps = [
        labels.paymentStatusSendingLockup,
        labels.paymentStatusLockupSent,
        labels.paymentStatusInvoicePaid,
        labels.paymentStatusCompleted,
      ];
      return _boltzSend(swap, steps, labels);
    case ChainSwap():
      if (swapReceiveObservable(swap)) {
        final steps = [
          labels.paymentStatusSendingLockup,
          labels.paymentStatusLockupSent,
          labels.paymentStatusClaimable,
          labels.paymentStatusClaimBroadcast,
          labels.paymentStatusConfirmed,
        ];
        final progress = swapTransitionProgress(
          swapId: swap.id,
          orderId: null,
          swap: swap,
          order: null,
          steps: steps,
          receiveTransaction: observed,
        );
        final phase = swapTransitionPhase(
          swapId: swap.id,
          orderId: null,
          swap: swap,
          order: null,
          receiveTransaction: observed,
        );
        return TransactionPaymentAnimation(
          network: BullPaymentNetwork.boltz,
          direction: BullPaymentDirection.outgoing,
          phase: phase,
          progress: progress,
          status: _status(progress, phase, labels),
        );
      }
      final steps = [
        labels.paymentStatusSendingLockup,
        labels.paymentStatusLockupSent,
        labels.paymentStatusClaimable,
        labels.paymentStatusClaimBroadcast,
      ];
      return _boltzSend(swap, steps, labels);
  }
}

TransactionPaymentAnimation _boltzSend(
  Swap swap,
  List<String> steps,
  TransactionsLocalizations labels,
) {
  final progress = boltzPaymentProgress(steps: steps, swap: swap);
  final phase = boltzPaymentPhase(swap) ?? BullPaymentPhase.sending;
  return TransactionPaymentAnimation(
    network: BullPaymentNetwork.boltz,
    direction: BullPaymentDirection.outgoing,
    phase: phase,
    progress: progress,
    status: _status(progress, phase, labels),
  );
}

TransactionPaymentAnimation _payjoin(
  Transaction transaction,
  PayjoinSession payjoin,
  TransactionsLocalizations labels, {
  required bool confirmed,
}) {
  final status = transaction.displayPayjoinStatus ?? payjoin.status;
  if (payjoin is PayjoinReceiverSession) {
    final steps = [
      labels.paymentStatusOriginalReceived,
      labels.paymentStatusProposalSent,
      labels.paymentStatusPaymentDetected,
      labels.paymentStatusConfirmed,
    ];
    final progress = receivePayjoinProgress(
      steps: steps,
      status: status,
      hasOriginal: payjoin.hasOriginalTransaction,
      hasProposal: payjoin.hasProposal,
      confirmed: confirmed,
    );
    final phase = receivePayjoinPhase(status: status, confirmed: confirmed);
    return TransactionPaymentAnimation(
      network: BullPaymentNetwork.payjoin,
      direction: BullPaymentDirection.incoming,
      phase: phase,
      progress: progress,
      status: _payjoinStatus(progress, phase, status, labels),
    );
  }
  final steps = [
    labels.paymentStatusRequested,
    labels.paymentStatusProposed,
    labels.paymentStatusBroadcasted,
    labels.paymentStatusConfirmed,
  ];
  final progress = payjoinPaymentProgress(steps: steps, status: status);
  final phase = payjoinPaymentPhase(status, confirmed: confirmed);
  return TransactionPaymentAnimation(
    network: BullPaymentNetwork.payjoin,
    direction: BullPaymentDirection.outgoing,
    phase: phase,
    progress: progress,
    status: _payjoinStatus(progress, phase, status, labels),
  );
}

String _payjoinStatus(
  BullPaymentProgress progress,
  BullPaymentPhase phase,
  PayjoinStatus status,
  TransactionsLocalizations labels,
) {
  if (status == PayjoinStatus.expired &&
      progress.currentState == BullPaymentStepState.held) {
    return labels.paymentStatusExpired;
  }
  return _status(progress, phase, labels, broadcastWording: true);
}

TransactionPaymentAnimation _buy(
  BuyOrder order,
  TransactionsLocalizations labels,
) {
  final network = buyPaymentNetwork(order);
  final steps = [
    labels.paymentStatusOrderPlaced,
    labels.paymentStatusBuyPayoutInProgress,
    if (network != BullPaymentNetwork.lightning) ...[
      labels.paymentStatusBuyPayoutBroadcast,
      labels.paymentStatusBuyPayoutSent,
    ] else
      labels.paymentStatusPaid,
  ];
  final progress = buyOrderPaymentProgress(steps: steps, order: order);
  final phase = buyOrderPaymentPhase(order);
  return TransactionPaymentAnimation(
    network: network,
    direction: BullPaymentDirection.incoming,
    phase: phase,
    progress: progress,
    status: _status(progress, phase, labels),
  );
}
