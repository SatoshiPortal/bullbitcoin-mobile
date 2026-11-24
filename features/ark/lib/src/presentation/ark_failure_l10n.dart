import 'package:bull_ui/bull_ui.dart';

import 'ark_l10n.dart';
import '../domain/ark_failure.dart';
import '../ui/ark_amount.dart' show formatArkSats;

extension ArkFailureL10n on ArkFailure {
  String toTranslated(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return switch (this) {
      ArkChildCollisionFailure() || ArkInvalidRequestFailure() => l10n.invalid,
      ArkDisabledFailure() => l10n.disabled,
      ArkReviewExpiredFailure() => l10n.expired,
      ArkOperationBusyFailure() => l10n.busy,
      ArkAccountRecoveryFailure() => l10n.recovery,
      ArkPaymentInsufficientFundsFailure() ||
      ArkExitAwaitingFeesFailure() => l10n.insufficient,
      ArkExitFeesUnfundedFailure(:final amount) => l10n.exitFeesUnfunded(
        formatArkSats(context, amount),
      ),
      ArkBoardBelowMinimumFailure(:final minimum) => l10n.boardMinimum(
        minimum.value.toInt(),
      ),
      ArkSubmissionUncertainFailure() => l10n.uncertain,
      ArkPrivacyDisclosureFailure() => l10n.privacy,
      ArkReminderUnavailableFailure() => l10n.notificationsUnavailable,
      ArkReminderMigrationFailure() => l10n.reminderMigrationPending,
      ArkServiceUnavailableFailure() ||
      ArkFeatureStorageFailure() ||
      ArkNetworkUnavailableFailure() ||
      ArkUnexpectedFailure() => l10n.unavailable,
    };
  }
}
