import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

enum RestoredSwapKind { lightningSend, lightningReceive, crossChain }

/// A swap returned by the Boltz restore endpoints, identified by its Boltz id.
class RestoredSwap {
  final String id;
  final RestoredSwapKind kind;

  /// Boltz swap status mapped to the app's status, for display.
  final SwapStatus status;

  /// True when on-chain funds are locked and not yet claimed/refunded — i.e. the
  /// swap can still be rescued (claimed or refunded). Drives whether the row is
  /// actionable; resolved/never-funded swaps are not.
  final bool recoverable;

  /// On-chain amount locked in the swap, in sats.
  final int amountSat;
  final DateTime createdAt;

  /// Boltz asset symbols, e.g. "BTC" / "L-BTC". Drive which chain a rescue
  /// claims/refunds onto.
  final String fromAsset;
  final String toAsset;

  const RestoredSwap({
    required this.id,
    required this.kind,
    required this.status,
    required this.recoverable,
    required this.amountSat,
    required this.createdAt,
    required this.fromAsset,
    required this.toAsset,
  });

  /// Whether the on-chain side this rescue acts on is Liquid (vs Bitcoin).
  /// Lightning swaps act on their on-chain leg; a chain claim lands on [toAsset],
  /// a chain refund returns on [fromAsset].
  bool get actsOnLiquid => switch (kind) {
    RestoredSwapKind.lightningSend => fromAsset == 'L-BTC',
    RestoredSwapKind.lightningReceive => toAsset == 'L-BTC',
    RestoredSwapKind.crossChain =>
      isRefundAction ? fromAsset == 'L-BTC' : toAsset == 'L-BTC',
  };

  /// A swap whose funds come back to us (refund) vs are claimed forward.
  ///
  /// Refund vs claim is a state property, not an asset one: the same chain-swap
  /// pair claims forward while the swap is live and refunds once it can no
  /// longer complete. Failed, expired and refunded are all possible refund
  /// cases — the last because `transaction.refunded` means boltz refunded its
  /// OWN lockup, signalling us to refund ours. We let the user attempt the
  /// refund to a wallet on the chain their lockup is on; if the lockup is
  /// already gone the on-chain refund fails (no UTXO), which is how we learn it
  /// was resolved.
  bool get isRefundAction =>
      status == SwapStatus.failed ||
      status == SwapStatus.expired ||
      status == SwapStatus.refunded;
}

/// A restored swap paired with whether it is already stored locally.
class RestorableSwap {
  final RestoredSwap swap;
  final bool existsLocally;

  const RestorableSwap({required this.swap, required this.existsLocally});

  /// Actionable here: on-chain funds locked & unresolved
  /// ([RestoredSwap.recoverable]) and not yet imported locally. Drives the
  /// pending-vs-completed display and whether a rescue can be attempted.
  bool get isRescuable => swap.recoverable && !existsLocally;
}
