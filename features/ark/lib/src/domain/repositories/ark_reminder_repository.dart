import 'package:meta/meta.dart';
import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../ark_expiry_warning.dart';
import '../ark_reminder_policy_evidence.dart';

export '../ark_reminder_policy_evidence.dart';

/// Implementations serialize reconciliation per account across engines. A
/// reminder survives restart; an unknown observation must never clear it.
abstract interface class ArkReminderRepository {
  @useResult
  Future<Result<void, ArkFailure>> reconcile({
    required ArkAccountId account,
    required ArkExpiryWarning? warning,
    required bool authoritativeEmpty,
    required int revision,
    required int tipHeight,
    ArkReminderPolicyEvidence? policyEvidence,
  });
}
