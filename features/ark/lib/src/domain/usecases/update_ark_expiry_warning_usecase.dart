import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../ark_expiry_warning.dart';
import '../repositories/ark_reminder_repository.dart';

final class UpdateArkExpiryWarningUsecase {
  final ArkReminderRepository _reminders;
  const UpdateArkExpiryWarningUsecase(this._reminders);

  Future<Result<void, ArkFailure>> execute(ArkSnapshot snapshot) {
    final warning = ArkExpiryWarning.fromSnapshot(snapshot);
    // An unknown/stale inventory or delegated round is never an empty wallet.
    final authoritativeEmpty =
        !snapshot.stale &&
        snapshot.vtxoInventoryComplete &&
        snapshot.tipHeight != null &&
        snapshot.obligations == ArkObligationStatus.none &&
        snapshot.pendingBoards.isEmpty &&
        !snapshot.operations.any(
          (operation) =>
              operation.kind == ArkOperationKind.board &&
              operation.status != ArkOperationStatus.succeeded &&
              operation.status != ArkOperationStatus.failed,
        ) &&
        snapshot.recovery == ArkRecoveryStatus.complete &&
        snapshot.renewal != ArkRenewalStatus.delegated &&
        snapshot.vtxos.every(
          (v) =>
              v.state == ArkVtxoState.spent || v.state == ArkVtxoState.exited,
        );
    if (warning == null && !authoritativeEmpty) {
      return Future.value(const Ok(null));
    }
    final tip = snapshot.tipHeight;
    if (tip == null) return Future.value(const Ok(null));
    return _reminders.reconcile(
      account: snapshot.account,
      warning: warning,
      authoritativeEmpty: authoritativeEmpty,
      revision: snapshot.revision,
      tipHeight: tip,
    );
  }
}
