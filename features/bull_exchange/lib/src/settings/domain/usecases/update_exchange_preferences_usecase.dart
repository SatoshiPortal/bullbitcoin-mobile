import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/exchange_preferences.dart';

/// Saves [patch] on [session]'s account (`Exchange.updatePreferences`).
typedef SaveAccountPreferences = Future<Result<void, ExchangeFailure>> Function(
  ExchangeSession session,
  ExchangePreferencesPatch patch,
);

class UpdateExchangePreferencesUsecase {
  final SaveAccountPreferences _save;
  final ExchangeWriteGate _writeGate;

  const UpdateExchangePreferencesUsecase({
    required this._save,
    required this._writeGate,
  });

  /// Sends only what the user changed from [loaded]: a field left alone is
  /// not overwritten, even if the account changed it meanwhile. The save runs
  /// through the write gate ([FinancialWriteKind.preferenceWrite]) of the
  /// session the screen opened for; without a session nothing is sent.
  @useResult
  Future<Result<void, ExchangeFailure>> execute(
    ExchangeSession? session, {
    required ExchangePreferences loaded,
    required ExchangePreferences edited,
  }) async => switch (session) {
    null => const Err(ExchangeNotAuthenticatedFailure()),
    final ExchangeSession session => await _writeGate.run(
      session,
      FinancialWriteKind.preferenceWrite,
      () => _send(session, loaded: loaded, edited: edited),
      refused: (refusal) => Err(ExchangeWriteBusyFailure(refusal)),
    ),
  };

  Future<Result<void, ExchangeFailure>> _send(
    ExchangeSession session, {
    required ExchangePreferences loaded,
    required ExchangePreferences edited,
  }) async {
    final result = await _save(
      session,
      ExchangePreferencesPatch(
        language: edited.language == loaded.language ? null : edited.language,
        currency: edited.currency == loaded.currency ? null : edited.currency,
        emailNotificationsEnabled:
            edited.emailNotificationsEnabled == loaded.emailNotificationsEnabled
            ? null
            : edited.emailNotificationsEnabled,
      ),
    );
    return result.mapErr(
      (failure) => switch (failure) {
        ExchangeNetworkFailure() => failure,
        ExchangeNotAuthenticatedFailure() || ExchangeSessionRejectedFailure() =>
          ExchangeNotAuthenticatedFailure(failure.logMessage),
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
          ExchangePreferencesSaveFailure(failure.logMessage),
      },
    );
  }
}
