import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [ExchangeFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
extension ExchangeFailureL10n on ExchangeFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ExchangeAccountUnavailableFailure() =>
      context.loc.exchangeAccountInfoLoadErrorMessage,
    ExchangeNotAuthenticatedFailure() => context.loc.exchangeAuthErrorMessage,
    ExchangeApiKeyStorageFailure() => context.loc.exchangeAuthErrorMessage,
    ExchangeSessionClearFailure() => context.loc.exchangeErrorSigningOut,
    ExchangePreferencesSaveFailure() =>
      context.loc.exchangeErrorSavingPreferences,
    // Infrastructure, not a user story: the socket is best-effort and the
    // cubit never surfaces this. It gets the generic string rather than a
    // message implying the user should do something about it.
    ExchangeNotificationsUnavailableFailure() =>
      context.loc.oopsSomethingWentWrong,
    ExchangeAnnouncementsUnavailableFailure() =>
      context.loc.exchangeErrorLoadingAnnouncements,
    ExchangeAccountDeletionRequestFailure() =>
      context.loc.exchangeErrorRequestingAccountDeletion,
    // Never `logMessage`. The legacy `BullException` chain interpolated the
    // raw `'$e'` into its message, so that field can carry anything.
    ExchangeUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
