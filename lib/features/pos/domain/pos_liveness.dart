/// Outcome kinds for the DG-3 Point of Sale recovery liveness check. The check
/// is READ-ONLY: it never issues a PUT and never re-registers.
enum PosLiveness {
  /// The pos row is present and not archived - nothing to do, nothing to render
  /// (the server never deletes rows; this is the normal case).
  live,

  /// The row is archived - the user's archive is respected; stay silent.
  archivedByUser,

  /// The registration is live but the pos row is genuinely absent (never
  /// created, or purged). The UI offers a one-tap recreate - the label and
  /// currency are unknowable client-side, so a silent re-create is impossible.
  needsReactivation,

  /// Network / timeout / server error - liveness is UNKNOWN; degrade loudly,
  /// never report [live] on a failure.
  unreachable,
}

class PosHealOutcome {
  final PosLiveness liveness;

  const PosHealOutcome({required this.liveness});
}
