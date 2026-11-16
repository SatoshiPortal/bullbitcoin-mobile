import 'package:ark/ark.dart';

/// An estimate, not a claim that Bitcoin blocks follow a clock. Safety UI must
/// retain the warning until an authoritative observation replaces the inputs.
final class ArkExpiryWarning {
  final Map<String, int> expiries;
  final DateTime notifyAt;
  final int revision;
  final int tipHeight;
  ArkExpiryWarning._(
    this.expiries,
    this.notifyAt,
    this.revision,
    this.tipHeight,
  );

  static ArkExpiryWarning? fromSnapshot(ArkSnapshot snapshot) {
    final tip = snapshot.tipHeight;
    if (snapshot.stale || !snapshot.vtxoInventoryComplete || tip == null) {
      return null;
    }
    final live = snapshot.vtxos
        .where(
          (v) =>
              v.state != ArkVtxoState.spent && v.state != ArkVtxoState.exited,
        )
        .toList();
    final expiries = {for (final v in live) 'vtxo:${v.id}': v.expiryHeight};
    for (final board in snapshot.pendingBoards) {
      final expiry = board.expiryHeight;
      if (expiry == null) return null;
      expiries['board:${board.vtxoId}'] = expiry;
    }
    for (final operation in snapshot.operations) {
      if (operation.kind != ArkOperationKind.board ||
          operation.status == ArkOperationStatus.succeeded ||
          operation.status == ArkOperationStatus.failed) {
        continue;
      }
      final funding = operation.boardFunding;
      if (funding == null) return null;
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
    );
  }

  bool sameInputs(ArkExpiryWarning other) =>
      expiries.length == other.expiries.length &&
      expiries.entries.every(
        (entry) => other.expiries[entry.key] == entry.value,
      );
}
