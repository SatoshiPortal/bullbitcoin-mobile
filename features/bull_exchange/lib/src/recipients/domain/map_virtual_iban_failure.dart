import 'package:exchange/exchange.dart';

/// The failure the virtual IBAN screens show for a failed virtual IBAN call.
ExchangeFailure mapVirtualIbanFailure(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() ||
      ExchangeNetworkFailure() ||
      ExchangeVirtualIbanNotAvailableFailure() ||
      ExchangeEuResidencyRequiredFailure() => failure,
      ExchangeCredentialReadFailure() => const ExchangeUnexpectedFailure(
        'Exchange credential unavailable',
      ),
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
      ExchangeUnexpectedFailure() ||
      ExchangeOperationStaleFailure() ||
      ExchangeUnsupportedNetworkFailure() ||
      ExchangeOrderInventoryUnavailableFailure() ||
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
      ExchangeJournalFailure() ||
      ExchangeDestinationUnavailableFailure() ||
      ExchangeDestinationInvalidFailure() ||
      ExchangeMissingFailure() ||
      ExchangeUnreachableFailure() ||
      ExchangeMalformedFailure() ||
      ExchangeSessionRejectedFailure() ||
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
        ExchangeUnexpectedFailure(failure.logMessage),
    };
