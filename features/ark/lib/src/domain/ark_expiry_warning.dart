import 'package:ark/ark.dart';

/// An estimate, not a claim that Bitcoin blocks follow a clock. Safety UI must
/// retain the warning until an authoritative observation replaces the inputs.
final class ArkExpiryWarning {
  final Map<String, int> expiries;
  final DateTime notifyAt;
  final int revision;
  final int tipHeight;
  final Set<String> retiredKeys;
  ArkExpiryWarning._(
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
    final live = snapshot.vtxos
        .where(
          (v) =>
              v.state != ArkVtxoState.spent && v.state != ArkVtxoState.exited,
        )
        .toList();
    final liveIds = live.map((v) => v.id).toSet();
    final observedReplacementIds = live
        .where(
          (v) =>
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
    final retired = <String>{
      for (final id in retiredIds) 'vtxo:$id',
      for (final id in retiredIds)
        if (!snapshot.pendingBoards.any((board) => board.vtxoId == id))
          'board:$id',
    };
    // Board operation.nativeReference is a funding transaction id, not a
    // VTXO id. Without durable exact alias history retain its prior bound.
    final expiries = {for (final v in live) 'vtxo:${v.id}': v.expiryHeight};
    for (final board in snapshot.pendingBoards) {
      final expiry = board.expiryHeight;
      if (expiry == null) continue;
      expiries['board:${board.vtxoId}'] = expiry;
    }
    for (final operation in snapshot.operations) {
      if (operation.kind != ArkOperationKind.board ||
          operation.status == ArkOperationStatus.succeeded ||
          operation.status == ArkOperationStatus.failed) {
        continue;
      }
      final funding = operation.boardFunding;
      if (funding == null) continue;
      expiries['funding:${operation.id}'] = funding.expiryHeight;
    }
    if (expiries.isEmpty) return null;
    final earliest = expiries.values.reduce((a, b) => a < b ? a : b);
    final estimatedExpiry = snapshot.observedAt.add(
      Duration(minutes: (earliest - tip) * 10),
    );
    return ArkExpiryWarning._(
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
