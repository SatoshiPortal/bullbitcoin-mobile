import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:boltz/boltz.dart' as boltz_pkg;

/// Pure decision logic for the notify-only swap background pass. Extracted
/// from the handler so it can be unit-tested without booting the full Workmanager
/// / GetIt / drift stack. No I/O, no side effects.

/// If [swap] currently requires user action, returns the [SwapStatus] that
/// best describes that action — this is what the notification copy keys off.
/// Returns null if no action is needed right now.
///
/// Combines the persisted [Swap.requiresAction] with a minimal Boltz
/// status → effective-state mapping per variant so the caller can notify on
/// a transition that hasn't been written back to storage yet.
SwapStatus? effectiveActionableStatus(Swap swap, boltz_pkg.SwapStatus? fresh) {
  if (swap.requiresAction) {
    // Failed LnSendSwap has `requiresAction == true` even when nothing was
    // locked on-chain (sendTxid null). Notifying for swaps with no
    // recoverable funds is spam — gate it on canRefund.
    if (swap is LnSendSwap && swap.status == SwapStatus.failed) {
      final canRefund = swap.sendTxid != null && swap.refundTxid == null;
      if (!canRefund) return null;
    }
    return swap.status;
  }
  if (fresh == null) return null;
  switch (swap) {
    case LnReceiveSwap s:
      // Reverse swap: claimable once the server-side HTLC is visible.
      final isLiquid = s.type == SwapType.lightningToLiquid;
      if (s.receiveTxid != null) return null;
      if (fresh == boltz_pkg.SwapStatus.invoiceSettled) {
        return SwapStatus.claimable;
      }
      if (isLiquid && fresh == boltz_pkg.SwapStatus.txnMempool) {
        return SwapStatus.claimable;
      }
      if (!isLiquid && fresh == boltz_pkg.SwapStatus.txnConfirmed) {
        return SwapStatus.claimable;
      }
      return null;
    case LnSendSwap s:
      // canCoop as soon as invoice is paid / claim is pending.
      if (fresh == boltz_pkg.SwapStatus.invoicePaid) return SwapStatus.canCoop;
      if (fresh == boltz_pkg.SwapStatus.txnClaimPending) {
        return SwapStatus.canCoop;
      }
      // Refundable once a failure lands with funds still locked on-chain.
      final canRefund = s.sendTxid != null && s.refundTxid == null;
      if (!canRefund) return null;
      return isFailureStatus(fresh) ? SwapStatus.failed : null;
    case ChainSwap s:
      // Claimable once Boltz has locked funds on the user's receive leg.
      final isLiquidTarget = s.type == SwapType.bitcoinToLiquid;
      final claimPending = s.receiveTxid == null;
      if (claimPending &&
          fresh == boltz_pkg.SwapStatus.txnServerMempool &&
          isLiquidTarget) {
        return SwapStatus.claimable;
      }
      if (claimPending && fresh == boltz_pkg.SwapStatus.txnServerConfirmed) {
        return SwapStatus.claimable;
      }
      if (claimPending && fresh == boltz_pkg.SwapStatus.txnClaimed) {
        return SwapStatus.claimable;
      }
      final canRefund = s.sendTxid != null && s.refundTxid == null;
      if (!canRefund) return null;
      return isFailureStatus(fresh) ? SwapStatus.failed : null;
  }
}

/// Picks the wallet whose detail view is most useful for the current swap
/// status. `Swap.walletId` is action-agnostic (always sendWalletId for
/// ChainSwap), which sends the user to the wrong screen on a `claimable`
/// chain swap. For external chain swaps (receiveWalletId == null) there is
/// no in-app claim path; we return null so the caller skips the notification.
String? notificationWalletId(Swap swap, SwapStatus effectiveStatus) {
  if (swap is ChainSwap && effectiveStatus == SwapStatus.claimable) {
    return swap.receiveWalletId;
  }
  return swap.walletId;
}

bool isFailureStatus(boltz_pkg.SwapStatus fresh) {
  return fresh == boltz_pkg.SwapStatus.invoiceFailedToPay ||
      fresh == boltz_pkg.SwapStatus.txnLockupFailed ||
      fresh == boltz_pkg.SwapStatus.txnFailed ||
      fresh == boltz_pkg.SwapStatus.txnRefunded ||
      fresh == boltz_pkg.SwapStatus.swapExpired ||
      fresh == boltz_pkg.SwapStatus.invoiceExpired ||
      fresh == boltz_pkg.SwapStatus.swapError ||
      fresh == boltz_pkg.SwapStatus.swapRefunded;
}
