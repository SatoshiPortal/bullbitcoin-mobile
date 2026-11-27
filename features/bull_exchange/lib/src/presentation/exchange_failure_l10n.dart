import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

import '../exchange_l10n.dart';
import '../payin/payin_l10n.dart';

/// User-facing, localized message for each [ExchangeFailure]: the one
/// translation of the exchange's failures. The `sealed` switch makes a
/// missing message a compile error. Never returns the raw `logMessage`: the
/// catch-all variants get the generic message.
extension ExchangeFailureL10n on ExchangeFailure {
  String toTranslated(BuildContext context) => switch (this) {
    // Session and account.
    ExchangeUnsupportedNetworkFailure() =>
      context.loc.networkFeatureUnavailable,
    ExchangeAccountUnavailableFailure() =>
      context.loc.exchangeAccountInfoLoadErrorMessage,
    ExchangeAccountDetailsUnavailableFailure() =>
      context.loc.exchangeSettingsErrorLoadingAccount,
    ExchangeNotAuthenticatedFailure() ||
    ExchangeSessionRejectedFailure() ||
    ExchangeAuthenticationDeferredFailure() ||
    ExchangeAuthenticationFailure() ||
    ExchangeApiKeyStorageFailure() => context.loc.exchangeAuthErrorMessage,
    ExchangeSessionClearFailure() => context.loc.exchangeErrorSigningOut,
    ExchangePlatformNotAllowedFailure() =>
      context.loc.exchangePlatformNotAllowedError,
    ExchangePreferencesSaveFailure() ||
    ExchangePreferencesSaveOutcomeUnknownFailure() =>
      context.loc.exchangeErrorSavingPreferences,
    ExchangeWriteBusyFailure() => context.loc.exchangeSettingsWriteBusy,
    // Infrastructure, not a user story: the socket is best-effort and the
    // cubit never surfaces this. It gets the generic string rather than a
    // message implying the user should do something about it.
    ExchangeNotificationsUnavailableFailure() =>
      context.loc.oopsSomethingWentWrong,
    ExchangeAnnouncementsUnavailableFailure() =>
      context.loc.exchangeErrorLoadingAnnouncements,
    ExchangeAccountDeletionRequestFailure() =>
      context.loc.exchangeErrorRequestingAccountDeletion,
    ExchangeNetworkFailure() || ExchangeUnreachableFailure(isNetwork: true) =>
      context.loc.exchangeErrorNetwork,
    // Settings: statistics and the secure document upload.
    ExchangeStatisticsUnavailableFailure() =>
      context.loc.exchangeSettingsErrorLoadingStatistics,
    ExchangeUploadStatusUnavailableFailure() =>
      context.loc.exchangeSettingsErrorLoadingUploadStatus,
    ExchangeDocumentAlreadySubmittedFailure() =>
      context.loc.exchangeSettingsErrorDocumentAlreadySubmitted,
    ExchangeDocumentEmptyFailure() =>
      context.loc.exchangeSettingsErrorDocumentEmpty,
    ExchangeDocumentTooLargeFailure() =>
      context.loc.exchangeSettingsErrorDocumentTooLarge,
    ExchangeDocumentTypeNotAllowedFailure() =>
      context.loc.exchangeSettingsErrorDocumentTypeNotAllowed,
    ExchangeDocumentUnreadableFailure() =>
      context.loc.exchangeSettingsErrorDocumentUnreadable,
    // The exchange's own rejection sentence lives in `logMessage` and stays
    // there; the user gets a message we wrote.
    ExchangeDocumentUploadFailure() =>
      context.loc.exchangeSettingsErrorUploadingDocument,
    // Payin and funding.
    ExchangePayinBuildFailure(:final problem) => problem.toTranslated(context),
    ExchangePaymentLinkUnavailableFailure() =>
      context.loc.fundExchangeErrorOpeningPaymentLink,
    // Default wallets.
    ExchangeDefaultWalletAddressEmptyFailure() =>
      context.loc.exchangeBitcoinWalletsAddressEmpty,
    ExchangeDefaultWalletAddressInvalidFailure(:final network) =>
      context.loc.destinationExpectedType(switch (network) {
        BtcNetwork.bitcoin => context.loc.exchangeDcaAddressLabelBitcoin,
        BtcNetwork.liquid => context.loc.exchangeDcaAddressLabelLiquid,
        BtcNetwork.lightning => context.loc.exchangeDcaAddressLabelLightning,
      }),
    ExchangeDefaultWalletSaveFailure() =>
      context.loc.exchangeBitcoinWalletsSaveFailed,
    ExchangeDefaultWalletDeleteFailure() =>
      context.loc.exchangeBitcoinWalletsDeleteFailed,
    // Support chat.
    ExchangeChatNotAuthenticatedFailure() =>
      context.loc.exchangeSupportLoginChatRequired,
    ExchangeChatLoadMessagesFailure() =>
      context.loc.exchangeSupportChatLoadMessagesError,
    ExchangeChatSendMessageFailure() =>
      context.loc.exchangeSupportChatSendMessageError,
    ExchangeChatMessageEmptyFailure() =>
      context.loc.exchangeSupportChatMessageEmptyError,
    ExchangeChatLoadAttachmentFailure() =>
      context.loc.exchangeSupportChatLoadAttachmentError,
    ExchangeChatAttachmentEmptyFailure() =>
      context.loc.exchangeSupportChatFetchFileDataFailed,
    ExchangeChatPickImagesFailure() =>
      context.loc.exchangeSupportChatPickFilesFailed,
    ExchangeChatAttachLogsFailure() =>
      context.loc.exchangeSupportChatAttachLogsFailed,
    // Recipients. Their reasons are JSON-RPC error objects and parse errors
    // over recipient payloads, carrying server internals and the user's own
    // banking details, so none is ever shown.
    ExchangeRecipientsLoadFailure() => context.loc.recipientsErrorLoadFailed,
    ExchangeRecipientsSaveFailure() => context.loc.recipientsErrorSaveFailed,
    final ExchangeRecipientsInvalidFieldsFailure refused =>
      context.loc.recipientsErrorFieldsRefused(
        refused.refusedFieldNames(except: const {}).join(', '),
      ),
    ExchangeRecipientsSaveOutcomeUnknownFailure() =>
      context.loc.recipientsErrorSaveOutcomeUnknown,
    ExchangeRecipientsSinpeLookupFailure() =>
      context.loc.recipientsErrorSinpeLookupFailed,
    ExchangeRecipientsCadBillerSearchFailure() =>
      context.loc.recipientsErrorBillerSearchFailed,
    ExchangeVirtualIbanNotAvailableFailure() =>
      context.loc.recipientsErrorVirtualIbanNotAvailable,
    ExchangeEuResidencyRequiredFailure() =>
      context.loc.recipientsErrorEuResidencyRequired,
    // Deliberately does NOT say the save failed: it succeeded, and a message
    // that implies otherwise invites a retry and a duplicate recipient.
    ExchangeRecipientsSavedButNotSelectedFailure() =>
      context.loc.recipientsErrorSavedButNotSelected,
    // The catch-all variants and the failures no screen words on its own: the
    // generic message, never `logMessage` (the legacy `BullException` chain
    // interpolated the raw `'$e'` into it, so it can carry anything).
    // ExchangeRecipientsSelectionFailure's cause belongs to the feature that supplied
    // the hook; InvalidSecurityDetails only comes back from the Interac
    // update withdraw drives after validating those fields itself.
    ExchangeRecipientsSelectionFailure() ||
    ExchangeRecipientsInvalidSecurityDetailsFailure() ||
    ExchangeUnexpectedFailure() ||
    ExchangeJournalFailure() ||
    ExchangeDestinationUnavailableFailure() ||
    ExchangeDestinationInvalidFailure() ||
    ExchangeFeeEstimatesUnavailableFailure() ||
    ExchangeWalletCoinsUnavailableFailure() ||
    ExchangeTransactionLookupFailure() ||
    ExchangeApiKeyInvalidFailure() ||
    ExchangeCredentialsUnavailableFailure() ||
    ExchangeBasicAuthSaveFailure() ||
    ExchangeApiKeySaveFailure() ||
    ExchangeApiKeyDeleteFailure() ||
    ExchangeOrderLimitFailure() ||
    ExchangeConfidentialSepaInactiveFailure() ||
    ExchangeOrderRejectedFailure() ||
    ExchangeOrderLoadFailure() ||
    ExchangeCredentialReadFailure() ||
    ExchangeConsentRegistrationFailure() ||
    ExchangeLimitOrderFailure() ||
    ExchangeFundingFailure() ||
    ExchangeOrderInventoryUnavailableFailure() ||
    ExchangeOperationStaleFailure() ||
    ExchangeUnreachableFailure(isNetwork: false) ||
    ExchangeMissingFailure() ||
    ExchangeMalformedFailure() ||
    ExchangeWriteRefusedFailure() ||
    ExchangeWriteOutcomeUnknownFailure() ||
    ExchangeWriteNotSentFailure() => context.loc.oopsSomethingWentWrong,
  };
}

/// The refused fields a recipient form names under each field, and the rest.
extension ExchangeRecipientsInvalidFieldsFailureL10n
    on ExchangeRecipientsInvalidFieldsFailure {
  /// The API names of the refused fields, leaving out the fields in [except]
  /// (the ones the form marks under the field itself).
  List<String> refusedFieldNames({required Set<RecipientField> except}) => [
    for (final field in fields.keys)
      if (!except.contains(field)) field.wireName,
    ...otherFields,
  ];

  /// The message under the Continue button of a form that marks the
  /// [shownFields] itself.
  String summary(BuildContext context, Set<RecipientField> shownFields) {
    final rest = refusedFieldNames(except: shownFields);
    return rest.isEmpty
        ? context.loc.recipientsErrorCheckFields
        : context.loc.recipientsErrorFieldsRefused(rest.join(', '));
  }
}

/// The message under a recipient form field the exchange refused.
extension RecipientFieldProblemL10n on RecipientFieldProblem {
  String toTranslated(BuildContext context) => switch (this) {
    RecipientFieldProblem.missing =>
      context.loc.recipientsValidationFieldRequired,
    RecipientFieldProblem.invalid => context.loc.recipientsErrorFieldRefused,
  };
}
