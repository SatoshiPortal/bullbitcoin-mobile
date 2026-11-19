import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

/// A saved signed claim selected from the account's trusted journal snapshot.
/// Its summary is display evidence; the package revalidates its private bytes.
final class ArkClaimRecoverySelection {
  final ArkAccountId account;
  final ArkOperation operation;
  final ArkClaimRecovery summary;
  const ArkClaimRecoverySelection._(this.account, this.operation, this.summary);

  static Result<ArkClaimRecoverySelection, ArkFailure> fromSnapshot(
    ArkAccountId account,
    String operationId,
    ArkSnapshot snapshot,
  ) {
    if (snapshot.account != account) return const Err(ArkUnexpectedFailure());
    final matches = snapshot.operations
        .where((o) => o.id == operationId)
        .toList();
    if (matches.length != 1) return const Err(ArkAccountRecoveryFailure());
    final operation = matches.single;
    final summary = operation.claimRecovery;
    final eligible = switch (operation.status) {
      ArkOperationStatus.prepared ||
      ArkOperationStatus.admitted ||
      ArkOperationStatus.pending ||
      ArkOperationStatus.outcomeUnknown => true,
      ArkOperationStatus.succeeded ||
      ArkOperationStatus.failed ||
      ArkOperationStatus.conflicted => false,
    };
    if (operation.kind != ArkOperationKind.claim ||
        summary == null ||
        !eligible) {
      return const Err(ArkAccountRecoveryFailure());
    }
    // Generic stale/recovery-complete and quote-expiry gates do not establish
    // authority for already signed bytes and must not strand their recovery.
    return Ok(ArkClaimRecoverySelection._(account, operation, summary));
  }
}
