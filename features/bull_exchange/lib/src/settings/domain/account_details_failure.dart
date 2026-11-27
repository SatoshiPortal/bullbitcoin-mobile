import 'package:exchange/exchange.dart';

/// The failure the account settings screens show for a failed account
/// summary read: a signed-out account asks to log in again, any other
/// failure is "the account details could not be loaded".
ExchangeFailure accountDetailsFailure(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() || ExchangeSessionRejectedFailure() =>
        const ExchangeNotAuthenticatedFailure(),
      ExchangeAccountUnavailableFailure() ||
      ExchangeAuthenticationDeferredFailure() ||
      ExchangeAuthenticationFailure() ||
      ExchangeApiKeyStorageFailure() ||
      ExchangeSessionClearFailure() ||
      ExchangePlatformNotAllowedFailure() ||
      ExchangePreferencesSaveFailure() ||
      ExchangePreferencesSaveOutcomeUnknownFailure() ||
      ExchangeNotificationsUnavailableFailure() ||
      ExchangeAnnouncementsUnavailableFailure() ||
      ExchangeAccountDeletionRequestFailure() ||
      ExchangeNetworkFailure() ||
      ExchangeUnexpectedFailure() ||
      ExchangeOperationStaleFailure() ||
      ExchangeUnsupportedNetworkFailure() ||
      ExchangeOrderInventoryUnavailableFailure() ||
      ExchangeCredentialReadFailure() ||
      ExchangeCredentialsUnavailableFailure() ||
      ExchangeBasicAuthSaveFailure() ||
      ExchangeApiKeyInvalidFailure() ||
      ExchangeApiKeySaveFailure() ||
      ExchangeApiKeyDeleteFailure() ||
      ExchangeOrderLimitFailure() ||
      ExchangeConfidentialSepaInactiveFailure() ||
      ExchangeOrderLoadFailure() ||
      ExchangeOrderRejectedFailure() ||
      ExchangeStatisticsUnavailableFailure() ||
      ExchangeDocumentUploadFailure() ||
      ExchangeAccountDetailsUnavailableFailure() ||
      ExchangeUploadStatusUnavailableFailure() ||
      ExchangeDocumentAlreadySubmittedFailure() ||
      ExchangeDocumentEmptyFailure() ||
      ExchangeDocumentTooLargeFailure() ||
      ExchangeDocumentTypeNotAllowedFailure() ||
      ExchangeDocumentUnreadableFailure() ||
      ExchangeWriteBusyFailure() ||
      ExchangePaymentLinkUnavailableFailure() ||
      ExchangeDefaultWalletAddressEmptyFailure() ||
      ExchangeDefaultWalletAddressInvalidFailure() ||
      ExchangeDefaultWalletSaveFailure() ||
      ExchangeDefaultWalletDeleteFailure() ||
      ExchangeConsentRegistrationFailure() ||
      ExchangeChatLoadMessagesFailure() ||
      ExchangeChatSendMessageFailure() ||
      ExchangeChatLoadAttachmentFailure() ||
      ExchangeChatNotAuthenticatedFailure() ||
      ExchangeChatMessageEmptyFailure() ||
      ExchangeChatAttachmentEmptyFailure() ||
      ExchangeChatPickImagesFailure() ||
      ExchangeChatAttachLogsFailure() ||
      ExchangeLimitOrderFailure() ||
      ExchangeFundingFailure() ||
      ExchangeVirtualIbanNotAvailableFailure() ||
      ExchangeEuResidencyRequiredFailure() ||
      ExchangeJournalFailure() ||
      ExchangeDestinationUnavailableFailure() ||
      ExchangeDestinationInvalidFailure() ||
      ExchangeFeeEstimatesUnavailableFailure() ||
      ExchangeWalletCoinsUnavailableFailure() ||
      ExchangeTransactionLookupFailure() ||
      ExchangeMissingFailure() ||
      ExchangeUnreachableFailure() ||
      ExchangeMalformedFailure() ||
      ExchangeWriteRefusedFailure() ||
      ExchangeWriteOutcomeUnknownFailure() ||
      ExchangeWriteNotSentFailure() ||
      ExchangePayinBuildFailure() ||
      ExchangeRecipientsLoadFailure() ||
      ExchangeRecipientsSaveFailure() ||
      ExchangeRecipientsInvalidFieldsFailure() ||
      ExchangeRecipientsSaveOutcomeUnknownFailure() ||
      ExchangeRecipientsSinpeLookupFailure() ||
      ExchangeRecipientsCadBillerSearchFailure() ||
      ExchangeRecipientsSelectionFailure() ||
      ExchangeRecipientsSavedButNotSelectedFailure() ||
      ExchangeRecipientsInvalidSecurityDetailsFailure() =>
        const ExchangeAccountDetailsUnavailableFailure(),
    };
