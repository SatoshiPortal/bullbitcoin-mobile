import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart' as swap_entity;
import 'package:bull_sdk/boltz.dart' as boltz;

/// Outcome of mapping an incoming Boltz status onto the locally stored swap.
sealed class SwapStatusMapping {
  const SwapStatusMapping();
}

/// Nothing to store for this event.
class SwapUnchanged extends SwapStatusMapping {
  const SwapUnchanged();
}

/// Store [swap] (and emit it when the status changed or action is needed).
class SwapUpdated extends SwapStatusMapping {
  final SwapModel swap;
  const SwapUpdated(this.swap);
}

/// Stale pending swap with provably no funds at risk — safe to delete
/// together with its secure-storage keys.
class SwapStale extends SwapStatusMapping {
  const SwapStale();
}

class SwapStatusMapper {
  const SwapStatusMapper();

  static const _stalePendingAge = Duration(days: 14);

  SwapStatusMapping map({
    required SwapModel swap,
    required boltz.SwapStatus boltzStatus,
    String? transactionId,
    required DateTime now,
  }) {
    final localStatus = _localStatus(swap);

    if (_isStalePending(swap, localStatus, boltzStatus, now)) {
      return const SwapStale();
    }

    final SwapModel? updated = _applyStatus(
      swap,
      localStatus,
      boltzStatus,
      transactionId,
      now,
    );

    if (updated == null) return const SwapUnchanged();

    final targetStatus = _localStatus(updated);
    if (targetStatus != localStatus &&
        !isAllowedTransition(from: localStatus, to: targetStatus, swap: swap)) {
      return const SwapUnchanged();
    }

    if (updated == swap) return const SwapUnchanged();

    return SwapUpdated(updated);
  }

  /// A pending swap older than [_stalePendingAge] may only be deleted when
  /// nothing was ever locked up: no sendTxid recorded AND Boltz itself says
  /// the swap expired without funds movement. Any transaction-related event
  /// instead flows through the normal mapping (which routes to refundable
  /// when funds are at risk). Swap data is otherwise kept forever, per the
  /// Boltz integration guidelines.
  bool _isStalePending(
    SwapModel swap,
    swap_entity.SwapStatus localStatus,
    boltz.SwapStatus boltzStatus,
    DateTime now,
  ) {
    if (localStatus != swap_entity.SwapStatus.pending) return false;
    if (boltzStatus != boltz.SwapStatus.swapExpired &&
        boltzStatus != boltz.SwapStatus.invoiceExpired) {
      return false;
    }
    if (_sendTxid(swap) != null) return false;
    final creationTime = DateTime.fromMillisecondsSinceEpoch(swap.creationTime);
    return now.difference(creationTime) > _stalePendingAge;
  }

  /// Boltz replays events and can deliver them out of order; this blocks a
  /// stale event from regressing a swap.
  bool isAllowedTransition({
    required swap_entity.SwapStatus from,
    required swap_entity.SwapStatus to,
    required SwapModel swap,
  }) {
    if (from == to) return true;

    if (from == swap_entity.SwapStatus.completed) {
      if (to != swap_entity.SwapStatus.claimable) return false;
      return switch (swap) {
        LnReceiveSwapModel(:final receiveTxid, :final wasDirectPayment) =>
          receiveTxid == null && !wasDirectPayment,
        ChainSwapModel(:final receiveTxid, :final refundTxid) =>
          receiveTxid == null && refundTxid == null,
        LnSendSwapModel() => false,
      };
    }
    if (from == swap_entity.SwapStatus.refunded) return false;

    // Expired/failed swaps with locked, unrefunded funds must be able to
    // become refundable — otherwise funds are stranded forever.
    if (from == swap_entity.SwapStatus.expired ||
        from == swap_entity.SwapStatus.failed) {
      final fundsAtRisk = _sendTxid(swap) != null && _refundTxid(swap) == null;
      if (to == swap_entity.SwapStatus.refundable) return fundsAtRisk;
      return to == swap_entity.SwapStatus.expired ||
          to == swap_entity.SwapStatus.failed ||
          to == swap_entity.SwapStatus.refunded;
    }

    // A refundable swap has funds locked awaiting refund; a later boltz
    // failure/expiry event must not regress it to terminal failed/expired and
    // strand them. (Rescued swaps don't record a sendTxid for _failureOutcome
    // to key on, so its reconcile re-map would otherwise downgrade them.) Only
    // resolved outcomes and the lateral move to claimable stay valid.
    if (from == swap_entity.SwapStatus.refundable) {
      return to == swap_entity.SwapStatus.refunded ||
          to == swap_entity.SwapStatus.completed ||
          to == swap_entity.SwapStatus.claimable ||
          to == swap_entity.SwapStatus.canCoop;
    }

    final fromRank = _rank(from);
    final toRank = _rank(to);
    if (toRank > fromRank) return true;
    // Lateral moves between action states follow the server's judgement
    // (e.g. claimable -> refundable when a chain swap lockup fails).
    if (toRank == fromRank && fromRank == 2) return true;
    return false;
  }

  int _rank(swap_entity.SwapStatus status) => switch (status) {
    swap_entity.SwapStatus.pending => 0,
    swap_entity.SwapStatus.paid => 1,
    swap_entity.SwapStatus.canCoop ||
    swap_entity.SwapStatus.claimable ||
    swap_entity.SwapStatus.refundable => 2,
    swap_entity.SwapStatus.completed ||
    swap_entity.SwapStatus.refunded ||
    swap_entity.SwapStatus.expired ||
    swap_entity.SwapStatus.failed => 3,
  };

  SwapModel? _applyStatus(
    SwapModel swap,
    swap_entity.SwapStatus localStatus,
    boltz.SwapStatus boltzStatus,
    String? transactionId,
    DateTime now,
  ) {
    final nowMs = now.millisecondsSinceEpoch;

    switch (boltzStatus) {
      case boltz.SwapStatus.swapCreated:
      case boltz.SwapStatus.invoiceSet:
      case boltz.SwapStatus.invoicePending:
      case boltz.SwapStatus.minerfeePaid:
        return null;

      // Magic Routing Hint direct payment: the sender paid our chain address
      // directly — no lockup exists and there is nothing to claim. Only mark
      // completed when Boltz reported the transaction id; otherwise hold at
      // paid and let reconciliation or the wallet's own tx detection settle
      // it (docs: transaction.direct is not a sole source of truth).
      case boltz.SwapStatus.txnDirect:
        if (swap is! LnReceiveSwapModel) return null;
        if (transactionId != null) {
          return swap.copyWith(
            receiveTxid: transactionId,
            wasDirectPayment: true,
            status: swap_entity.SwapStatus.completed.name,
            completionTime: nowMs,
          );
        }
        return swap.copyWith(
          wasDirectPayment: true,
          status: swap_entity.SwapStatus.paid.name,
        );

      // The invoice is paid: the send swap's purpose is fulfilled. The coop
      // close handshake is driven by txnClaimPending; completion by
      // txnClaimed.
      case boltz.SwapStatus.invoicePaid:
        if (swap is! LnSendSwapModel) return null;
        return swap.copyWith(
          status: swap_entity.SwapStatus.paid.name,
          completionTime: nowMs,
        );

      case boltz.SwapStatus.txnClaimPending:
        if (swap is! LnSendSwapModel) return null;
        return swap.copyWith(status: swap_entity.SwapStatus.canCoop.name);

      case boltz.SwapStatus.invoiceSettled:
        if (swap is! LnReceiveSwapModel) return null;
        if (swap.receiveTxid != null || swap.wasDirectPayment) {
          if (localStatus == swap_entity.SwapStatus.completed) return null;
          return swap.copyWith(
            status: swap_entity.SwapStatus.completed.name,
            completionTime: swap.completionTime ?? nowMs,
          );
        }
        return swap.copyWith(status: swap_entity.SwapStatus.claimable.name);

      case boltz.SwapStatus.invoiceFailedToPay:
        if (swap is! LnSendSwapModel) return null;
        return _failureOutcome(swap, nowMs);

      case boltz.SwapStatus.txnMempool:
        switch (swap) {
          case LnReceiveSwapModel():
            // Liquid lockups are claimed 0-conf; Bitcoin waits for
            // confirmation.
            final claimableAtMempool =
                swap.type == swap_entity.SwapType.lightningToLiquid.name;
            return swap.copyWith(
              status: claimableAtMempool
                  ? swap_entity.SwapStatus.claimable.name
                  : swap_entity.SwapStatus.paid.name,
            );
          case LnSendSwapModel():
          case ChainSwapModel():
            return swap.copyWith(status: swap_entity.SwapStatus.paid.name);
        }

      case boltz.SwapStatus.txnConfirmed:
        switch (swap) {
          case LnReceiveSwapModel():
            return swap.copyWith(status: swap_entity.SwapStatus.claimable.name);
          case LnSendSwapModel():
          case ChainSwapModel():
            return swap.copyWith(status: swap_entity.SwapStatus.paid.name);
        }

      case boltz.SwapStatus.txnClaimed:
        switch (swap) {
          case LnSendSwapModel():
            return swap.copyWith(
              status: swap_entity.SwapStatus.completed.name,
              completionTime: swap.completionTime ?? nowMs,
            );
          case ChainSwapModel():
            if (swap.receiveTxid == null) {
              return swap.copyWith(
                status: swap_entity.SwapStatus.claimable.name,
              );
            }
            return swap.copyWith(
              status: swap_entity.SwapStatus.completed.name,
              completionTime: swap.completionTime ?? nowMs,
            );
          case LnReceiveSwapModel():
            return null;
        }

      // Boltz refunded its own lockup. For a reverse swap that means the
      // swap failed (we never claimed). For send/chain swaps our own lockup
      // may still need refunding.
      case boltz.SwapStatus.txnRefunded:
      case boltz.SwapStatus.swapRefunded:
        switch (swap) {
          case LnReceiveSwapModel():
            return swap.copyWith(status: swap_entity.SwapStatus.failed.name);
          case LnSendSwapModel():
          case ChainSwapModel():
            return _failureOutcome(swap, nowMs);
        }

      case boltz.SwapStatus.txnLockupFailed:
      case boltz.SwapStatus.txnFailed:
        switch (swap) {
          case LnReceiveSwapModel():
            // Boltz could not lock up; the Lightning payment is cancelled
            // and no user funds are at risk.
            return swap.copyWith(status: swap_entity.SwapStatus.failed.name);
          case LnSendSwapModel():
          case ChainSwapModel():
            return _failureOutcome(swap, nowMs);
        }

      case boltz.SwapStatus.swapExpired:
      case boltz.SwapStatus.invoiceExpired:
        switch (swap) {
          case LnReceiveSwapModel():
            // MRH lifecycle ends in swap.expired even though the user was
            // paid directly on-chain — expiry must never relabel a direct
            // payment (boltz docs + issue #1920).
            if (swap.wasDirectPayment) return null;
            return swap.copyWith(status: swap_entity.SwapStatus.expired.name);
          case LnSendSwapModel():
          case ChainSwapModel():
            return _failureOutcome(
              swap,
              nowMs,
              noFundsStatus: swap_entity.SwapStatus.expired,
            );
        }

      case boltz.SwapStatus.swapError:
        switch (swap) {
          case LnReceiveSwapModel():
            return swap.copyWith(status: swap_entity.SwapStatus.failed.name);
          case LnSendSwapModel():
          case ChainSwapModel():
            return _failureOutcome(swap, nowMs);
        }

      case boltz.SwapStatus.txnServerMempool:
      case boltz.SwapStatus.txnServerConfirmed:
        if (swap is! ChainSwapModel) return null;
        // Liquid server lockups are claimed 0-conf; Bitcoin server lockups
        // need a confirmation.
        final receivingLiquid =
            swap.type == swap_entity.SwapType.bitcoinToLiquid.name;
        final claimable =
            boltzStatus == boltz.SwapStatus.txnServerConfirmed ||
            (receivingLiquid &&
                boltzStatus == boltz.SwapStatus.txnServerMempool);
        return swap.copyWith(
          status: claimable
              ? swap_entity.SwapStatus.claimable.name
              : swap_entity.SwapStatus.paid.name,
        );
    }
  }

  SwapModel _failureOutcome(
    SwapModel swap,
    int nowMs, {
    swap_entity.SwapStatus noFundsStatus = swap_entity.SwapStatus.failed,
  }) {
    final hasSentFunds = _sendTxid(swap) != null;
    final hasRefunded = _refundTxid(swap) != null;

    final swap_entity.SwapStatus target;
    int? completionTime;
    if (hasRefunded) {
      target = swap_entity.SwapStatus.refunded;
      completionTime = nowMs;
    } else if (hasSentFunds) {
      target = swap_entity.SwapStatus.refundable;
    } else {
      target = noFundsStatus;
    }

    return switch (swap) {
      LnSendSwapModel() => swap.copyWith(
        status: target.name,
        completionTime: completionTime ?? swap.completionTime,
      ),
      ChainSwapModel() => swap.copyWith(
        status: target.name,
        completionTime: completionTime ?? swap.completionTime,
      ),
      LnReceiveSwapModel() => swap,
    };
  }

  swap_entity.SwapStatus _localStatus(SwapModel swap) =>
      swap_entity.SwapStatus.values.firstWhere(
        (s) => s.name == swap.status,
        orElse: () => swap_entity.SwapStatus.pending,
      );

  String? _sendTxid(SwapModel swap) => switch (swap) {
    LnReceiveSwapModel() => null,
    LnSendSwapModel(:final sendTxid) => sendTxid,
    ChainSwapModel(:final sendTxid) => sendTxid,
  };

  String? _refundTxid(SwapModel swap) => switch (swap) {
    LnReceiveSwapModel() => null,
    LnSendSwapModel(:final refundTxid) => refundTxid,
    ChainSwapModel(:final refundTxid) => refundTxid,
  };
}
