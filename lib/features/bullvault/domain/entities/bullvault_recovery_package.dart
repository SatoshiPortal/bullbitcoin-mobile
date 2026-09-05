import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';

final class BullVaultRecoveryPackage {
  final String? previousVaultId;
  final BullVaultPolicy policy;

  const BullVaultRecoveryPackage({this.previousVaultId, required this.policy});

  bool canBeEnrichedBy(BullVaultRecoveryPackage other) {
    final incoming = other.policy;
    final schedule = policy.schedule;
    final incomingSchedule = incoming.schedule;
    return policy.descriptor == incoming.descriptor &&
        policy.network == incoming.network &&
        (policy.birthHeight == null ||
            policy.birthHeight == incoming.birthHeight) &&
        (policy.createdAt == null || policy.createdAt == incoming.createdAt) &&
        (previousVaultId == null || previousVaultId == other.previousVaultId) &&
        (policy.lineageId == incoming.lineageId ||
            policy.lineageId == policy.id &&
                previousVaultId == null &&
                policy.createdAt == null &&
                policy.birthHeight == null &&
                schedule == null) &&
        (schedule == null ||
            incomingSchedule != null &&
                schedule.unit == incomingSchedule.unit &&
                schedule.recoveryDelay == incomingSchedule.recoveryDelay &&
                (policy.coldActivationTimestamp == null ||
                    schedule.coldDelay == incomingSchedule.coldDelay) &&
                (policy.inheritanceKey == null ||
                    schedule.inheritanceDelay ==
                        incomingSchedule.inheritanceDelay));
  }
}
