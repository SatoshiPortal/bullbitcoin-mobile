import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/models/transaction_detail_view.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/swap_progress.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/transaction_section_contributor.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/tx_format.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

/// Boltz swaps — covers all subtypes (LN↔BTC/Liquid reverse & submarine, and
/// BTC↔Liquid chain swaps). Owns the whole presentation for a swap so there is
/// a single, authoritative status. Intermediary protocol detail (swap id,
/// counterpart tx id, preimage) is folded behind the transaction-id row's
/// expand toggle rather than shown by default.
class SwapSectionContributor extends TransactionSectionContributor {
  const SwapSectionContributor();

  @override
  int get priority => 30;

  @override
  bool appliesTo(Transaction tx) => tx.isSwap;

  @override
  TxHeaderView? header(Transaction tx, TxPresentDeps deps) {
    final swap = tx.swap!;
    final loc = deps.loc;
    final isInProgress = !swap.status.isTerminal;

    final String label;
    var tone = TxStatusTone.normal;
    if (isInProgress) {
      label = swap.isChainSwap
          ? loc.transactionStatusTransferInProgress
          : loc.transactionStatusPaymentInProgress;
    } else if (swap.swapCompleted && swap.isChainSwap) {
      label = loc.transactionStatusTransferCompleted;
    } else if (swap.swapRefunded) {
      label = loc.transactionStatusPaymentRefunded;
    } else if (swap.status == SwapStatus.failed) {
      tone = TxStatusTone.error;
      label = swap.isChainSwap
          ? loc.transactionStatusTransferFailed
          : loc.transactionStatusSwapFailed;
    } else if (swap.status == SwapStatus.expired) {
      tone = TxStatusTone.errorMuted;
      label = swap.isChainSwap
          ? loc.transactionStatusTransferExpired
          : loc.transactionStatusSwapExpired;
    } else {
      label = tx.isIncoming
          ? loc.transactionFilterReceive
          : loc.transactionFilterSend;
    }

    return TxHeaderView(
      isIncoming: tx.isIncoming,
      isTransfer: swap.isChainSwap,
      statusLabel: label,
      tone: tone,
      amount: TxAmountView(sats: _headerAmountSat(tx, swap)),
    );
  }

  int _headerAmountSat(Transaction tx, Swap swap) {
    final isExternalChainSwap =
        swap is ChainSwap && swap.receiveWalletId == null;
    if (isExternalChainSwap) return swap.receieveAmount ?? 0;
    if (tx.isOutgoing) return swap.amountSat;
    return swap.receieveAmount ?? 0;
  }

  @override
  TxProgressView? progress(Transaction tx, TxPresentDeps deps) {
    final swap = tx.swap!;
    final loc = deps.loc;
    final p = swapProgressOf(swap, loc);

    final String summary;
    if (swap.swapRefunded) {
      summary = loc.transactionDetailLabelRefunded;
    } else if (p.state == TxProgressState.completed) {
      summary = swap.status.displayName(loc);
    } else if (p.state == TxProgressState.failed) {
      summary = swap.status.displayName(loc);
    } else {
      summary = loc.transactionSwapProgressStepStatus(
        p.currentStep + 1,
        p.totalSteps,
      );
    }

    return TxProgressView(
      label: swap.isChainSwap
          ? loc.transactionDetailLabelTransferStatus
          : loc.transactionDetailLabelSwapStatus,
      summaryLabel: summary,
      steps: p.steps,
      currentStep: p.currentStep,
      state: p.state,
      detailMessage: swap.getDisplayMessage(loc),
    );
  }

  @override
  List<TxCallout> callouts(Transaction tx, TxPresentDeps deps) {
    final swap = tx.swap!;
    // Only ongoing swaps surface the contextual status box + safety warning.
    if (swap.status.isTerminal) return const [];
    final loc = deps.loc;

    final footnote = _additionalInfo(swap, loc);
    return [
      TxCallout(
        tone: TxCalloutTone.info,
        title: swap.isChainSwap
            ? loc.transactionSwapStatusTransferStatus
            : loc.transactionSwapStatusSwapStatus,
        body: _statusDescription(swap, loc),
        footnote: footnote.isEmpty ? null : footnote,
        infoCardBody: swap.isChainSwap
            ? '${loc.transactionSwapDoNotUninstall}\n\n'
                  '${loc.transactionSwapOpenWithin24h}'
            : loc.transactionSwapDoNotUninstall,
      ),
    ];
  }

  @override
  List<TxDetailRow> rows(Transaction tx, TxPresentDeps deps) {
    final swap = tx.swap!;
    final loc = deps.loc;
    final txId = tx.txId;
    final recipientAddress = swap.receiveAddress ?? tx.toAddress;
    final fees = swap.fees;

    // The user's lockup tx fee for a send/chain swap: prefer the persisted
    // lockupFee, fall back to the linked lockup tx's actual fee.
    final swapSendNetworkFee = (fees?.lockupFee ?? 0) > 0
        ? fees!.lockupFee!
        : (tx.walletTransaction?.feeSat ?? 0);

    final technicalRows = _technicalDetailRows(tx, swap, deps);

    return [
      // Primary identifier row with the protocol detail folded behind it.
      if (txId != null)
        TxDetailRow(
          label: loc.transactionDetailLabelTransactionId,
          value: TxId(
            txId,
            isLiquid: tx.isLiquid,
            isTestnet: tx.isTestnet,
            unblindedUrl: tx.walletTransaction?.unblindedUrl,
          ),
          copyValue: txId,
          expandedRows: technicalRows,
        )
      else
        TxDetailRow(
          label: swap.isChainSwap
              ? loc.transactionDetailLabelTransferId
              : loc.transactionDetailLabelSwapId,
          value: TxText(swap.id),
          copyValue: swap.id,
          expandedRows: technicalRows
              .where((r) => r.label != _swapIdLabel(swap, loc))
              .toList(),
        ),
      if (recipientAddress != null && recipientAddress.isNotEmpty)
        TxDetailRow(
          label: loc.transactionDetailLabelRecipientAddress,
          value: TxAddress(recipientAddress),
          copyValue: recipientAddress,
        ),
      if (swap.sendAmount != null)
        TxDetailRow(
          label: loc.transactionLabelSendAmount,
          value: TxAmount(swap.sendAmount!),
        ),
      if (swap.receieveAmount != null)
        TxDetailRow(
          label: loc.transactionLabelReceiveAmount,
          value: TxAmount(swap.receieveAmount!),
        ),
      if (!swap.isLnReceiveSwap && swapSendNetworkFee > 0)
        TxDetailRow(
          label: loc.transactionLabelSendNetworkFees,
          value: TxAmount(swapSendNetworkFee),
        ),
      if (fees != null)
        TxDetailRow(
          label: swap.type.isChain
              ? loc.transactionDetailLabelTransferFees
              : loc.transactionDetailLabelSwapFees,
          value: TxAmount(
            swap.isLnReceiveSwap
                ? fees.totalFees(swap.amountSat)
                : fees.totalFeesMinusLockup(swap.amountSat),
          ),
          expandedNote: swap.isLnReceiveSwap
              ? loc.transactionFeesDeductedFrom
              : loc.transactionFeesTotalDeducted,
          expandedRows: [
            if (swap.isLnReceiveSwap && fees.lockupFee != null)
              TxDetailRow(
                label: loc.transactionDetailLabelSendNetworkFee,
                value: TxAmount(fees.lockupFee!),
              ),
            if (fees.claimFee != null)
              TxDetailRow(
                label: loc.transactionLabelReceiveNetworkFee,
                value: TxAmount(fees.claimFee!),
              ),
            if (fees.serverNetworkFees != null)
              TxDetailRow(
                label: loc.transactionLabelServerNetworkFees,
                value: TxAmount(fees.serverNetworkFees!),
              ),
            TxDetailRow(
              label: loc.transactionDetailLabelTransferFee,
              value: TxAmount(fees.boltzFee ?? 0),
            ),
          ],
        ),
      TxDetailRow(
        label: loc.transactionDetailLabelCreatedAt,
        value: TxText(formatTxDate(swap.creationTime)),
      ),
      if (swap.completionTime != null)
        TxDetailRow(
          label: loc.transactionDetailLabelCompletedAt,
          value: TxText(formatTxDate(swap.completionTime!)),
        ),
    ];
  }

  String _swapIdLabel(Swap swap, AppLocalizations loc) => swap.isChainSwap
      ? loc.transactionDetailLabelTransferId
      : loc.transactionDetailLabelSwapId;

  List<TxDetailRow> _technicalDetailRows(
    Transaction tx,
    Swap swap,
    TxPresentDeps deps,
  ) {
    final loc = deps.loc;
    final counterpartTxId = deps.swapCounterpartTxId;
    final preimage = swap is LnSendSwap ? swap.preimage : null;

    return [
      TxDetailRow(
        label: _swapIdLabel(swap, loc),
        value: TxText(swap.id),
        copyValue: swap.id,
      ),
      if (counterpartTxId != null)
        TxDetailRow(
          label: deps.counterpartWallet?.isLiquid == true
              ? loc.transactionDetailLabelLiquidTxId
              : loc.transactionDetailLabelBitcoinTxId,
          value: TxText(StringFormatting.truncateMiddle(counterpartTxId)),
          copyValue: counterpartTxId,
        ),
      if (preimage != null && preimage.isNotEmpty)
        TxDetailRow(
          label: loc.transactionLabelPreimage,
          value: TxText(
            StringFormatting.truncateMiddle(preimage, head: 6, tail: 6),
          ),
          copyValue: preimage,
        ),
    ];
  }

  String _statusDescription(Swap swap, AppLocalizations loc) {
    if (swap is LnReceiveSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return loc.transactionSwapDescLnReceivePending;
        case SwapStatus.paid:
          return loc.transactionSwapDescLnReceivePaid;
        case SwapStatus.claimable:
          return loc.transactionSwapDescLnReceiveClaimable;
        case SwapStatus.completed:
          return loc.transactionSwapDescLnReceiveCompleted;
        case SwapStatus.failed:
          return loc.transactionSwapDescLnReceiveFailed;
        case SwapStatus.expired:
          return loc.transactionSwapDescLnReceiveExpired;
        default:
          return loc.transactionSwapDescLnReceiveDefault;
      }
    } else if (swap is LnSendSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return loc.transactionSwapDescLnSendPending;
        case SwapStatus.paid:
          return loc.transactionSwapDescLnSendPaid;
        case SwapStatus.completed:
          return loc.transactionSwapDescLnSendCompleted;
        case SwapStatus.refunded:
          return loc.coreSwapsLnSendCompletedRefunded;
        case SwapStatus.failed:
          return loc.transactionSwapDescLnSendFailed;
        case SwapStatus.expired:
          return loc.transactionSwapDescLnSendExpired;
        default:
          return loc.transactionSwapDescLnSendDefault;
      }
    } else if (swap is ChainSwap) {
      switch (swap.status) {
        case SwapStatus.pending:
          return loc.transactionSwapDescChainPending;
        case SwapStatus.paid:
          return loc.transactionSwapDescChainPaid;
        case SwapStatus.claimable:
          return loc.transactionSwapDescChainClaimable;
        case SwapStatus.refundable:
          return loc.transactionSwapDescChainRefundable;
        case SwapStatus.completed:
          return loc.transactionSwapDescChainCompleted;
        case SwapStatus.refunded:
          return loc.coreSwapsChainCompletedRefunded;
        case SwapStatus.failed:
          return loc.transactionSwapDescChainFailed;
        case SwapStatus.expired:
          return loc.transactionSwapDescChainExpired;
        default:
          return loc.transactionSwapDescChainDefault;
      }
    }
    return loc.transactionSwapDescChainDefault;
  }

  String _additionalInfo(Swap swap, AppLocalizations loc) {
    if (swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) {
      return loc.transactionSwapInfoFailedExpired;
    }
    if (swap.isChainSwap &&
        (swap.status == SwapStatus.pending ||
            swap.status == SwapStatus.paid)) {
      return loc.transactionSwapInfoChainDelay;
    }
    if (swap.status == SwapStatus.claimable) {
      return swap.isChainSwap
          ? loc.transactionSwapInfoClaimableTransfer
          : loc.transactionSwapInfoClaimableSwap;
    }
    if (swap.status == SwapStatus.refundable) {
      return swap.isChainSwap
          ? loc.transactionSwapInfoRefundableTransfer
          : loc.transactionSwapInfoRefundableSwap;
    }
    return '';
  }
}
