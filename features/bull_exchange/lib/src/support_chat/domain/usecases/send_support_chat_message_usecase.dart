import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class SendSupportChatMessageUsecase {
  final Exchange _exchange;

  const SendSupportChatMessageUsecase({required this._exchange});

  /// Sends [text] with [attachments]; a message without attachments is sent
  /// without the attachments field.
  @useResult
  Future<Result<void, ExchangeFailure>> execute(
    ExchangeSession? session, {
    required String text,
    List<SupportChatMessageAttachment> attachments = const [],
  }) async =>
      (switch (session) {
        null => const Err<void, ExchangeFailure>(
          ExchangeNotAuthenticatedFailure(),
        ),
        final ExchangeSession session => await _exchange.sendSupportMessage(
          session,
          text: text,
          attachments: attachments.isEmpty ? null : attachments,
        ),
      }).mapErr(
        (failure) => switch (failure) {
          ExchangeNotAuthenticatedFailure() =>
            const ExchangeChatNotAuthenticatedFailure(),
          ExchangeChatSendMessageFailure() => failure,
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
