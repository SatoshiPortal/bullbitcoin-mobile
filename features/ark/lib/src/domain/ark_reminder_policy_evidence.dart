import 'package:ark/ark.dart';

/// Exact historical namespace candidates, never settlement or custody proof.
final class ArkReminderPolicyEvidence {
  final ArkAccountId account;
  final int revision;
  final int? tipHeight;
  final Set<String> vtxoKeys;
  final Set<String> fundingKeys;
  const ArkReminderPolicyEvidence._(
    this.account,
    this.revision,
    this.tipHeight,
    this.vtxoKeys,
    this.fundingKeys,
  );

  factory ArkReminderPolicyEvidence.fromSnapshot(ArkSnapshot snapshot) {
    final pending = snapshot.pendingBoards.map((b) => b.vtxoId).toSet();
    return ArkReminderPolicyEvidence._(
      snapshot.account,
      snapshot.revision,
      snapshot.tipHeight,
      Set.unmodifiable({
        for (final v in snapshot.vtxos)
          if (!pending.contains(v.id) || v.state == ArkVtxoState.spendable)
            'vtxo:${v.id}',
      }),
      Set.unmodifiable({
        for (final b in snapshot.pendingBoards) 'board:${b.vtxoId}',
        for (final op in snapshot.operations)
          if (op.kind == ArkOperationKind.board) 'funding:${op.id}',
      }),
    );
  }
}
