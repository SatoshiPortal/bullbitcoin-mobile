import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:flutter/widgets.dart';

extension BullVaultFailureL10n on BullVaultFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BullVaultInvalidSignerFailure() =>
      context.loc.bullVaultFailureInvalidSigner,
    BullVaultSignerReuseFailure() => context.loc.bullVaultFailureSignerReuse,
    BullVaultInvalidScheduleFailure() =>
      context.loc.bullVaultFailureInvalidSchedule,
    BullVaultClockMismatchFailure() =>
      context.loc.bullVaultFailureClockMismatch,
    BullVaultReviewExpiredFailure() =>
      context.loc.bullVaultFailureReviewExpired,
    BullVaultCreationFailure() => context.loc.oopsSomethingWentWrong,
    BullVaultBackupStatusFailure() => context.loc.oopsSomethingWentWrong,
    BullVaultRenewalFailure() => context.loc.oopsSomethingWentWrong,
    BullVaultInvalidRecoveryFailure() =>
      context.loc.bullVaultFailureInvalidRecovery,
  };
}
