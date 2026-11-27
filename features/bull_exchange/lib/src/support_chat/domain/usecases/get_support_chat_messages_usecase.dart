import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetSupportChatMessagesUsecase {
  final Exchange _exchange;

  const GetSupportChatMessagesUsecase({required this._exchange});

  @useResult
  Future<Result<List<SupportChatMessage>, ExchangeFailure>> execute(
    ExchangeSession? session, {
    int? page,
    int? pageSize,
  }) async =>
      (switch (session) {
        null => const Err<List<SupportChatMessage>, ExchangeFailure>(
          ExchangeNotAuthenticatedFailure(),
        ),
        final ExchangeSession session => await _exchange.getSupportMessages(
          session,
          page: page,
          pageSize: pageSize,
        ),
      }).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() =>
            const ExchangeChatNotAuthenticatedFailure(),
          ExchangeChatLoadMessagesFailure() => failure,
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
