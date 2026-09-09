import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:boltz_swaps/boltz_swaps.dart';

extension SwapStatusL10nX on SwapStatus {
  String displayName(BuildContext context) {
    switch (this) {
      case SwapStatus.pending:
        return context.loc.coreSwapsStatusPending;
      case SwapStatus.paid:
      case SwapStatus.claimable:
      case SwapStatus.refundable:
      case SwapStatus.canCoop:
        return context.loc.coreSwapsStatusInProgress;
      case SwapStatus.completed:
        return context.loc.coreSwapsStatusCompleted;
      case SwapStatus.refunded:
        return context.loc.coreSwapsStatusRefunded;
      case SwapStatus.expired:
        return context.loc.coreSwapsStatusExpired;
      case SwapStatus.failed:
        return context.loc.coreSwapsStatusFailed;
    }
  }
}

extension SwapActionL10nX on Swap {
  String swapAction(BuildContext context) => status == SwapStatus.claimable
      ? context.loc.coreSwapsActionClaim
      : status == SwapStatus.canCoop
      ? context.loc.coreSwapsActionClose
      : status == SwapStatus.refundable
      ? context.loc.coreSwapsActionRefund
      : '';
}

extension SwapStatusMessage on Swap {
  String getDisplayMessage(BuildContext context) {
    if (isLnReceiveSwap) {
      switch (status) {
        case SwapStatus.pending:
          return context.loc.coreSwapsLnReceivePending;
        case SwapStatus.paid:
          return context.loc.coreSwapsLnReceivePaid;
        case SwapStatus.claimable:
          return context.loc.coreSwapsLnReceiveClaimable;
        case SwapStatus.refundable:
          return context.loc.coreSwapsLnReceiveRefundable;
        case SwapStatus.canCoop:
          return context.loc.coreSwapsLnReceiveCanCoop;
        case SwapStatus.completed:
          return context.loc.coreSwapsLnReceiveCompleted;
        case SwapStatus.refunded:
          return context.loc.coreSwapsLnReceiveFailed;
        case SwapStatus.expired:
          return context.loc.coreSwapsLnReceiveExpired;
        case SwapStatus.failed:
          return context.loc.coreSwapsLnReceiveFailed;
      }
    } else if (isLnSendSwap) {
      switch (status) {
        case SwapStatus.pending:
          return context.loc.coreSwapsLnSendPending;
        case SwapStatus.paid:
          return context.loc.coreSwapsLnSendPaid;
        case SwapStatus.claimable:
          return context.loc.coreSwapsLnSendClaimable;
        case SwapStatus.refundable:
          return context.loc.coreSwapsLnSendRefundable;
        case SwapStatus.canCoop:
          return context.loc.coreSwapsLnSendCanCoop;
        case SwapStatus.completed:
          final swap = this;
          if (swap is LnSendSwap && swap.refundTxid != null) {
            return context.loc.coreSwapsLnSendCompletedRefunded;
          } else {
            return context.loc.coreSwapsLnSendCompletedSuccess;
          }
        case SwapStatus.refunded:
          return context.loc.coreSwapsLnSendCompletedRefunded;
        case SwapStatus.expired:
          return context.loc.coreSwapsLnSendExpired;
        case SwapStatus.failed:
          final swap = this;
          if (swap is LnSendSwap && swap.sendTxid != null) {
            return context.loc.coreSwapsLnSendFailedRefunding;
          } else {
            return context.loc.coreSwapsLnSendFailed;
          }
      }
    } else if (isChainSwap) {
      switch (status) {
        case SwapStatus.pending:
          return context.loc.coreSwapsChainPending;
        case SwapStatus.paid:
          return context.loc.coreSwapsChainPaid;
        case SwapStatus.claimable:
          return context.loc.coreSwapsChainClaimable;
        case SwapStatus.refundable:
          return context.loc.coreSwapsChainRefundable;
        case SwapStatus.canCoop:
          return context.loc.coreSwapsChainCanCoop;
        case SwapStatus.completed:
          final swap = this;
          if (swap is ChainSwap && swap.refundTxid != null) {
            return context.loc.coreSwapsChainCompletedRefunded;
          } else {
            return context.loc.coreSwapsChainCompletedSuccess;
          }
        case SwapStatus.refunded:
          return context.loc.coreSwapsChainCompletedRefunded;
        case SwapStatus.expired:
          return context.loc.coreSwapsChainExpired;
        case SwapStatus.failed:
          final swap = this;
          if (swap is ChainSwap && swap.sendTxid != null) {
            return context.loc.coreSwapsChainFailedRefunding;
          } else {
            return context.loc.coreSwapsChainFailed;
          }
      }
    }
    return "";
  }
}
