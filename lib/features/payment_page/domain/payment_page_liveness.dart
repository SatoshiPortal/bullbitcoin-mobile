/// Outcome kinds for the DG-3 Donation Page recovery liveness check. The check
/// is READ-ONLY: it never issues a PUT and never re-registers.
enum PaymentPageLiveness {
  /// The page row is present and not archived — nothing to do, nothing to
  /// render (the server never deletes rows; this is the normal case).
  live,

  /// The row is archived — the user's archive is respected; stay silent.
  archivedByUser,

  /// The registration is live but the page row is genuinely absent (never
  /// created, or purged). The UI offers a one-tap recreate — the content is
  /// unknowable client-side, so a silent re-create is impossible.
  needsReactivation,

  /// Network / timeout / server error — liveness is UNKNOWN; degrade loudly,
  /// never report [live] on a failure.
  unreachable,
}

class PaymentPageHealOutcome {
  final PaymentPageLiveness liveness;

  const PaymentPageHealOutcome({required this.liveness});
}
