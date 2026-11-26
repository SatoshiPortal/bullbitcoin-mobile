import 'package:ark/ark.dart';

/// Selects only fully observed exit groups for an advisory notification.
///
/// A journalled start is the durable group identity. Missing or ambiguous
/// members and any claim journal entry make the group ineligible.
bool hasFreshExitObservation(ArkAccountId account, ArkPassOutcome pass) {
  final snapshot = pass.snapshot;
  return snapshot.account == account &&
      !snapshot.stale &&
      snapshot.recovery == ArkRecoveryStatus.complete &&
      snapshot.tipHeight != null &&
      pass.failedStages.isEmpty &&
      pass.failedStageKinds.isEmpty &&
      pass.submittedRounds.isEmpty &&
      pass.completedStages.contains(ArkStage.exits);
}

Set<String> claimableExitGroups(ArkAccountId account, ArkPassOutcome pass) {
  final snapshot = pass.snapshot;
  if (!hasFreshExitObservation(account, pass)) return {};

  if (snapshot.operations.any(
    (operation) =>
        operation.kind == ArkOperationKind.claim && operation.actualIds.isEmpty,
  )) {
    return {};
  }
  final exits = <String, List<ArkExit>>{};
  for (final exit in snapshot.exitDetails) {
    (exits[exit.id] ??= []).add(exit);
  }
  final starts = snapshot.operations
      .where(
        (operation) =>
            operation.kind == ArkOperationKind.emergencyExit &&
            operation.actualIds.isNotEmpty,
      )
      .toList();
  final claimed = {
    for (final operation in snapshot.operations)
      if (operation.kind == ArkOperationKind.claim) ...operation.actualIds,
  };
  final memberships = <String, int>{};
  for (final start in starts) {
    for (final id in start.actualIds.toSet()) {
      memberships[id] = (memberships[id] ?? 0) + 1;
    }
  }
  return {
    for (final start in starts)
      if (start.skippedIds.isEmpty &&
          start.actualIds.toSet().length == start.actualIds.length &&
          start.actualIds.every((id) {
            final matches = exits[id];
            return memberships[id] == 1 &&
                !claimed.contains(id) &&
                matches != null &&
                matches.length == 1 &&
                matches.single.status == ArkExitStatus.claimable &&
                matches.single.claimTxid == null;
          }))
        start.id,
  };
}
