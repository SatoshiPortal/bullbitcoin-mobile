import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

import 'exchange_l10n.dart';

/// User-facing, localized message for each [ExchangeFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
extension ExchangeFailureL10n on ExchangeFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ExchangeUnsupportedNetworkFailure() =>
      context.loc.networkFeatureUnavailable,
    ExchangeAccountUnavailableFailure() =>
      context.loc.exchangeAccountInfoLoadErrorMessage,
    ExchangeNotAuthenticatedFailure() ||
    ExchangeSessionRejectedFailure() => context.loc.exchangeAuthErrorMessage,
    ExchangeAuthenticationDeferredFailure() =>
      context.loc.exchangeAuthErrorMessage,
    ExchangeAuthenticationFailure() => context.loc.exchangeAuthErrorMessage,
    ExchangeApiKeyStorageFailure() => context.loc.exchangeAuthErrorMessage,
    ExchangeSessionClearFailure() => context.loc.exchangeErrorSigningOut,
    ExchangePreferencesSaveFailure() ||
    ExchangePreferencesSaveOutcomeUnknownFailure() =>
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
    ExchangeNetworkFailure() => context.loc.exchangeErrorNetwork,
    // Never `logMessage`. The legacy `BullException` chain interpolated the
    // raw `'$e'` into its message, so that field can carry anything.
    RecipientsFailure() ||
    ExchangeUnexpectedFailure() ||
    ExchangeApiKeyInvalidFailure() ||
    ExchangeApiKeySaveFailure() ||
    ExchangeApiKeyDeleteFailure() ||
    ExchangeOrderLimitFailure() ||
    ExchangeConfidentialSepaInactiveFailure() ||
    ExchangeOrderRejectedFailure() ||
    ExchangeOrderLoadFailure() ||
    ExchangeCredentialReadFailure() ||
    ExchangeStatisticsUnavailableFailure() ||
    ExchangeDocumentUploadFailure() ||
    ExchangeConsentRegistrationFailure() ||
    ExchangeChatLoadMessagesFailure() ||
    ExchangeChatSendMessageFailure() ||
    ExchangeChatLoadAttachmentFailure() ||
    ExchangeLimitOrderFailure() ||
    ExchangeFundingFailure() ||
    ExchangeVirtualIbanNotAvailableFailure() ||
    ExchangeEuResidencyRequiredFailure() ||
    ExchangeOrderInventoryUnavailableFailure() ||
    ExchangeOperationStaleFailure() => context.loc.oopsSomethingWentWrong,
  };
}
