import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// The read result of an exchange call that answers the whole
/// `Result<T, ExchangeFailure>`: its failure narrowed to an
/// [ExchangeReadFailure]. A failure is never read as a value.
Result<T, ExchangeReadFailure> readOfResult<T>(
  Result<T, ExchangeFailure> result,
) => switch (result) {
  Ok(:final value) => Ok(value),
  Err(:final failure) => readOfExchangeFailure(failure),
};

Result<T, ExchangeReadFailure> readOfExchangeFailure<T>(
  ExchangeFailure failure,
) => switch (failure) {
  final ExchangeReadFailure read => Err(read),
  ExchangeNotAuthenticatedFailure() => const Err(
    ExchangeSessionRejectedFailure(ExchangeSessionRejection.signedOut),
  ),
  ExchangeCredentialReadFailure() => const Err(
    ExchangeSessionRejectedFailure(
      ExchangeSessionRejection.credentialUnavailable,
    ),
  ),
  ExchangeNetworkFailure() => Err(
    ExchangeUnreachableFailure(failure.runtimeType.toString(), isNetwork: true),
  ),
  // Any other failure left the read without an answer.
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
  ExchangeVirtualIbanNotAvailableFailure() ||
  ExchangeEuResidencyRequiredFailure() ||
  ExchangeJournalFailure() ||
  ExchangeDestinationUnavailableFailure() ||
  ExchangeDestinationInvalidFailure() ||
  ExchangeFeeEstimatesUnavailableFailure() ||
  ExchangeWalletCoinsUnavailableFailure() ||
  ExchangeTransactionLookupFailure() ||
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
  ExchangeRecipientsInvalidSecurityDetailsFailure() => Err(
    ExchangeUnreachableFailure(
      failure.runtimeType.toString(),
      isNetwork: false,
    ),
  ),
};

/// The write result of an exchange write that answers the whole
/// `Result<T, ExchangeFailure>`: its failure narrowed to an
/// [ExchangeWriteFailure]. Only a failure that proves the write never
/// left the app is NotSent, and only a server refusal is Refused: everything
/// else may have reached the exchange and is OutcomeUnknown, so the step
/// re-reads instead of writing again.
Result<T, ExchangeWriteFailure> writeOfResult<T>(
  Result<T, ExchangeFailure> result,
) => switch (result) {
  Ok(:final value) => Ok(value),
  Err(:final failure) => switch (failure) {
    final ExchangeWriteFailure write => Err(write),
    ExchangeNotAuthenticatedFailure() => const Err(
      ExchangeWriteNotSentFailure(ExchangeNotSentReason.signedOut),
    ),
    ExchangeCredentialReadFailure() => const Err(
      ExchangeWriteNotSentFailure(ExchangeNotSentReason.credentialUnavailable),
    ),
    ExchangeOperationStaleFailure() => const Err(
      ExchangeWriteNotSentFailure(ExchangeNotSentReason.sessionChanged),
    ),
    ExchangeOrderRejectedFailure(:final apiCode, :final rpcCode) => Err(
      ExchangeWriteRefusedFailure(
        ExchangeRefusal(apiCode: apiCode, rpcCode: rpcCode),
      ),
    ),
    ExchangeVirtualIbanNotAvailableFailure() ||
    ExchangeEuResidencyRequiredFailure() ||
    ExchangeVirtualIbanNotAvailableFailure() ||
    ExchangeEuResidencyRequiredFailure() => const Err(
      ExchangeWriteRefusedFailure(ExchangeRefusal()),
    ),
    // Any other failure may have reached the exchange.
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
    ExchangeFeeEstimatesUnavailableFailure() ||
    ExchangeWalletCoinsUnavailableFailure() ||
    ExchangeTransactionLookupFailure() ||
    ExchangeMissingFailure() ||
    ExchangeUnreachableFailure() ||
    ExchangeMalformedFailure() ||
    ExchangePayinBuildFailure() ||
    ExchangeRecipientsLoadFailure() ||
    ExchangeRecipientsSaveFailure() ||
    ExchangeRecipientsInvalidFieldsFailure() ||
    ExchangeRecipientsSaveOutcomeUnknownFailure() ||
    ExchangeRecipientsSinpeLookupFailure() ||
    ExchangeRecipientsCadBillerSearchFailure() ||
    ExchangeRecipientsSelectionFailure() ||
    ExchangeRecipientsSavedButNotSelectedFailure() ||
    ExchangeRecipientsInvalidSecurityDetailsFailure() => Err(
      ExchangeWriteOutcomeUnknownFailure(failure.runtimeType.toString()),
    ),
  },
};
