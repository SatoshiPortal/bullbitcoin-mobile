import 'package:ark/ark.dart';

/// Candidates that can be priced individually when the full wallet inventory
/// is stale. The client still verifies chain and fee evidence before spending.
Iterable<ArkVtxo> arkExitCandidates(ArkSnapshot snapshot) {
  final tip = snapshot.tipHeight;
  if (tip == null) return const [];
  final needsProof = snapshot.stale || !snapshot.vtxoInventoryComplete;
  if (needsProof && snapshot.recovery != ArkRecoveryStatus.complete) {
    return const [];
  }
  final boards = {
    if (needsProof)
      for (final operation in snapshot.operations)
        if (operation.kind == ArkOperationKind.board &&
            operation.status == ArkOperationStatus.succeeded &&
            operation.boardFunding?.scuttleToken != null)
          ...operation.actualIds,
  };
  return snapshot.vtxos.where(
    (vtxo) =>
        vtxo.state == ArkVtxoState.spendable &&
        !vtxo.pendingRound &&
        vtxo.expiryHeight > tip &&
        (!needsProof || boards.contains(vtxo.id)),
  );
}
