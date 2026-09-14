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
    BullVaultRenewalHasFundsFailure() =>
      context.loc.bullVaultCancelRenewalHasFunds,
    BullVaultInvalidRecoveryFailure() =>
      context.loc.bullVaultFailureInvalidRecovery,
    // A policy can hold five signer keys at most, so no vault this app creates
    // can reach it; C12 gives it a message if publication ever surfaces one.
    BullVaultDescriptorBackupUnsupportedFailure() =>
      context.loc.oopsSomethingWentWrong,
    // C11's destination screens and C10's words entry are the first screens
    // that can reach these three, and they give each one its wording.
    BullVaultBackupCredentialFailure() ||
    BullVaultBackupWordsFailure() ||
    BullVaultNostrUnreachableFailure() => context.loc.oopsSomethingWentWrong,
  };
}
