import 'package:ark/ark.dart';

/// An estimate, not a claim that Bitcoin blocks follow a clock. Safety UI must
/// retain the warning until an authoritative observation replaces the inputs.
final class ArkExpiryWarning {
  final ArkAccountId account;
  final Map<String, int> expiries;
  final DateTime notifyAt;
  final int revision;
  final int tipHeight;
  final Set<String> retiredKeys;
  ArkExpiryWarning._(
    this.account,
    this.expiries,
    this.notifyAt,
    this.revision,
    this.tipHeight,
    this.retiredKeys,
  );

  static ArkExpiryWarning? fromSnapshot(ArkSnapshot snapshot) {
    final tip = snapshot.tipHeight;
    if (tip == null) {
      return null;
    }
    final pendingBoards = snapshot.pendingBoards.map((b) => b.vtxoId).toSet();
    bool admitsBound(ArkVtxo vtxo) =>
        !pendingBoards.contains(vtxo.id) ||
        vtxo.state == ArkVtxoState.spendable;
    final notRetired = snapshot.vtxos
        .where(
          (v) =>
              v.state != ArkVtxoState.spent && v.state != ArkVtxoState.exited,
        )
        .toList();
    // An abandoned Board is not a new expiry obligation, but its presence
    // cannot prove that an earlier obligation was retired by a renewal.
    final liveIds = notRetired.map((v) => v.id).toSet();
    final live = notRetired
        .where((v) => v.state != ArkVtxoState.abandonedBoard)
        .toList();
    final observedReplacementIds = live
        .where(
          (v) =>
              admitsBound(v) &&
              (v.state == ArkVtxoState.spendable ||
                  v.state == ArkVtxoState.locked) &&
              !v.pendingRound,
        )
        .map((v) => v.id)
        .toSet();
    final retiredIds = <String>{};
    // Positive known expiries may tighten alarms even during degraded reads.
    // Retirement needs the stronger complete, fresh observation predicate.
    final mayRetire =
        !snapshot.stale &&
        snapshot.vtxoInventoryComplete &&
        snapshot.recovery == ArkRecoveryStatus.complete &&
        snapshot.renewal != ArkRenewalStatus.delegated;
    for (final movement in snapshot.movements) {
      if (mayRetire &&
          movement.kind == ArkMovementKind.renewal &&
          movement.status == ArkMovementStatus.successful &&
          movement.inputVtxoIds.isNotEmpty &&
          movement.outputVtxoIds.isNotEmpty &&
          movement.inputVtxoIds.every((id) => !liveIds.contains(id)) &&
          movement.outputVtxoIds.every(observedReplacementIds.contains)) {
        retiredIds.addAll(movement.inputVtxoIds);
      }
    }
    final retired = {for (final id in retiredIds) 'vtxo:$id'};
    final expiries = {
      for (final v in live)
        if (admitsBound(v)) 'vtxo:${v.id}': v.expiryHeight,
    };
    if (expiries.isEmpty) return null;
    final earliest = expiries.values.reduce((a, b) => a < b ? a : b);
    final estimatedExpiry = snapshot.observedAt.add(
      Duration(minutes: (earliest - tip) * 10),
    );
    return ArkExpiryWarning._(
      snapshot.account,
      Map.unmodifiable(expiries),
      estimatedExpiry.subtract(const Duration(hours: 24)),
      snapshot.revision,
      tip,
      Set.unmodifiable(retired),
    );
  }

  /// Each obligation retains its earliest admitted deadline until positive
  /// linked replacement, never just disappearance from the current inventory.
  Map<String, DateTime> get deadlines {
    final earliest = expiries.values.reduce((a, b) => a < b ? a : b);
    return Map.unmodifiable({
      for (final entry in expiries.entries)
        entry.key: notifyAt.add(
          Duration(minutes: (entry.value - earliest) * 10),
        ),
    });
  }

  bool sameInputs(ArkExpiryWarning other) =>
      expiries.length == other.expiries.length &&
      expiries.entries.every(
        (entry) => other.expiries[entry.key] == entry.value,
      );
}
