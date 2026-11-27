import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessageAttachmentUsecase {
  final Exchange _exchange;

  const GetSupportChatMessageAttachmentUsecase({required this._exchange});

  @useResult
  Future<Result<SupportChatMessageAttachment, ExchangeFailure>> execute(
    ExchangeSession? session,
    String attachmentId,
  ) async =>
      (switch (session) {
        null => const Err<SupportChatMessageAttachment, ExchangeFailure>(
          ExchangeNotAuthenticatedFailure(),
        ),
        final ExchangeSession session => await _exchange.getSupportAttachment(
          session,
          attachmentId,
        ),
      }).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() =>
            const ExchangeChatNotAuthenticatedFailure(),
          ExchangeChatLoadAttachmentFailure() => failure,
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
            const ExchangeUnexpectedFailure(),
        },
      );
}
