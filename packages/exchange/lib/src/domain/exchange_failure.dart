import 'package:primitives/primitives.dart' show Failure;

import 'entities/btc_network.dart';

part 'exchange_call_failure.dart';
part '../recipients/domain/recipients_failure.dart';

/// Recoverable exchange failures. Consumers localize them at the UI boundary.
///
/// Never render `logMessage`. Keep it free of server text, credentials and
/// request data; it is reserved for sanitized diagnostics.
sealed class ExchangeFailure extends Failure {
  const ExchangeFailure([super.logMessage]);
}

/// No exchange session is stored, so there is no account to act on — the
/// actionable signal is "log in", not "retry".
final class ExchangeNotAuthenticatedFailure extends ExchangeFailure {
  const ExchangeNotAuthenticatedFailure([super.logMessage]);
}

/// The signed-in account could not be read, so balances, KYC level and
/// preferences are all unknown.
final class ExchangeAccountUnavailableFailure extends ExchangeFailure {
  const ExchangeAccountUnavailableFailure([super.logMessage]);
}

/// The web request was rejected before a credential was generated.
/// Leave the WebView open so authentication can continue.
final class ExchangeAuthenticationDeferredFailure extends ExchangeFailure {
  const ExchangeAuthenticationDeferredFailure();
}

/// The web authentication response could not provide a usable credential.
final class ExchangeAuthenticationFailure extends ExchangeFailure {
  const ExchangeAuthenticationFailure([super.logMessage]);
}

/// The API key returned by the auth flow could not be stored, so the session
/// would not survive. The user has to sign in again.
final class ExchangeApiKeyStorageFailure extends ExchangeFailure {
  const ExchangeApiKeyStorageFailure([super.logMessage]);
}

/// Signing out did not fully clear the stored session.
final class ExchangeSessionClearFailure extends ExchangeFailure {
  const ExchangeSessionClearFailure([super.logMessage]);
}

/// The platform policy does not let the exchange be turned on here.
final class ExchangePlatformNotAllowedFailure extends ExchangeFailure {
  const ExchangePlatformNotAllowedFailure([super.logMessage]);
}

/// Language, currency, notification or DCA preferences could not be saved.
final class ExchangePreferencesSaveFailure extends ExchangeFailure {
  const ExchangePreferencesSaveFailure([super.logMessage]);
}

/// The preference save may have reached the exchange without a readable
/// answer. A save replaces the whole set with the same values, so saving
/// again can't duplicate anything; callers treat it like a failed save.
final class ExchangePreferencesSaveOutcomeUnknownFailure
    extends ExchangeFailure {
  const ExchangePreferencesSaveOutcomeUnknownFailure([super.logMessage]);
}

/// The notification socket could not be opened. Non-blocking: the exchange is
/// fully usable without it, so this is logged rather than shown.
final class ExchangeNotificationsUnavailableFailure extends ExchangeFailure {
  const ExchangeNotificationsUnavailableFailure([super.logMessage]);
}

/// The announcement banner could not be filled. Non-blocking: the exchange is
/// perfectly usable without it.
final class ExchangeAnnouncementsUnavailableFailure extends ExchangeFailure {
  const ExchangeAnnouncementsUnavailableFailure([super.logMessage]);
}

/// The account-deletion request could not be sent to support.
final class ExchangeAccountDeletionRequestFailure extends ExchangeFailure {
  const ExchangeAccountDeletionRequestFailure([super.logMessage]);
}

/// The exchange API could not be reached, or timed out. Its own variant because
/// it is the one failure with advice the user can act on: check the connection.
final class ExchangeNetworkFailure extends ExchangeFailure {
  const ExchangeNetworkFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class ExchangeUnexpectedFailure extends ExchangeFailure {
  const ExchangeUnexpectedFailure([super.logMessage]);
}

/// A completion belongs to an access epoch that has already ended.
final class ExchangeOperationStaleFailure extends ExchangeFailure {
  const ExchangeOperationStaleFailure();
}

/// This environment has no supported exchange backend.
final class ExchangeUnsupportedNetworkFailure extends ExchangeFailure {
  const ExchangeUnsupportedNetworkFailure();
}

/// The server did not provide enough evidence to establish the order inventory.
final class ExchangeOrderInventoryUnavailableFailure extends ExchangeFailure {
  const ExchangeOrderInventoryUnavailableFailure();
}

/// The credential store could not supply an authoritative answer.
final class ExchangeCredentialReadFailure extends ExchangeFailure {
  const ExchangeCredentialReadFailure();
}

/// The Exchange credential store is missing, unreadable or not admitted. It is
/// never recreated, because an empty store would read as a signed-out user.
final class ExchangeCredentialsUnavailableFailure extends ExchangeFailure {
  const ExchangeCredentialsUnavailableFailure();
}

/// The testnet Basic Auth could not be stored.
final class ExchangeBasicAuthSaveFailure extends ExchangeFailure {
  const ExchangeBasicAuthSaveFailure();
}

/// A stored credential could not be decoded.
final class ExchangeApiKeyInvalidFailure extends ExchangeFailure {
  const ExchangeApiKeyInvalidFailure([super.logMessage]);
}

final class ExchangeApiKeySaveFailure extends ExchangeFailure {
  const ExchangeApiKeySaveFailure([super.logMessage]);
}

final class ExchangeApiKeyDeleteFailure extends ExchangeFailure {
  const ExchangeApiKeyDeleteFailure([super.logMessage]);
}

enum ExchangeOrderAmountBound { minimum, maximum }

final class ExchangeOrderLimitFailure extends ExchangeFailure {
  final ExchangeOrderAmountBound bound;
  final double amount;
  final String currency;

  const ExchangeOrderLimitFailure(this.bound, this.amount, this.currency);
}

final class ExchangeConfidentialSepaInactiveFailure extends ExchangeFailure {
  const ExchangeConfidentialSepaInactiveFailure();
}

final class ExchangeOrderLoadFailure extends ExchangeFailure {
  const ExchangeOrderLoadFailure();
}

/// Server refusal with safe codes only; the response may echo request data.
final class ExchangeOrderRejectedFailure extends ExchangeFailure {
  final String? apiCode;
  final int? rpcCode;

  const ExchangeOrderRejectedFailure({this.apiCode, this.rpcCode});
}

/// The trading statistics could not be retrieved.
final class ExchangeStatisticsUnavailableFailure extends ExchangeFailure {
  const ExchangeStatisticsUnavailableFailure([super.logMessage]);
}

/// The document was read but the exchange rejected or dropped the upload.
///
/// The API's own sentence arrives in `logMessage` and stays there.
final class ExchangeDocumentUploadFailure extends ExchangeFailure {
  const ExchangeDocumentUploadFailure([super.logMessage]);
}

/// The account details of the settings screens could not be retrieved.
final class ExchangeAccountDetailsUnavailableFailure extends ExchangeFailure {
  const ExchangeAccountDetailsUnavailableFailure([super.logMessage]);
}

/// The secure file upload status could not be retrieved.
final class ExchangeUploadStatusUnavailableFailure extends ExchangeFailure {
  const ExchangeUploadStatusUnavailableFailure([super.logMessage]);
}

/// A document has already been submitted, so no further upload is accepted.
final class ExchangeDocumentAlreadySubmittedFailure extends ExchangeFailure {
  const ExchangeDocumentAlreadySubmittedFailure([super.logMessage]);
}

/// The chosen file is empty.
final class ExchangeDocumentEmptyFailure extends ExchangeFailure {
  const ExchangeDocumentEmptyFailure([super.logMessage]);
}

/// The chosen file exceeds the size the exchange accepts.
final class ExchangeDocumentTooLargeFailure extends ExchangeFailure {
  const ExchangeDocumentTooLargeFailure([super.logMessage]);
}

/// The chosen file is not one of the accepted document formats.
final class ExchangeDocumentTypeNotAllowedFailure extends ExchangeFailure {
  const ExchangeDocumentTypeNotAllowedFailure([super.logMessage]);
}

/// The chosen file could not be read off the device.
final class ExchangeDocumentUnreadableFailure extends ExchangeFailure {
  const ExchangeDocumentUnreadableFailure([super.logMessage]);
}

/// Another exchange write of the account is running, or the journal can't
/// tell whether one is unsettled: nothing was sent.
final class ExchangeWriteBusyFailure extends ExchangeFailure {
  const ExchangeWriteBusyFailure();
}

/// The COP payment link could not be handed to a browser, so the user cannot
/// reach the payment page from here.
final class ExchangePaymentLinkUnavailableFailure extends ExchangeFailure {
  const ExchangePaymentLinkUnavailableFailure([super.logMessage]);
}

/// The default-wallet address field is empty.
final class ExchangeDefaultWalletAddressEmptyFailure extends ExchangeFailure {
  const ExchangeDefaultWalletAddressEmptyFailure();
}

/// The default-wallet address is not a [network] address.
final class ExchangeDefaultWalletAddressInvalidFailure extends ExchangeFailure {
  final BtcNetwork network;

  const ExchangeDefaultWalletAddressInvalidFailure(this.network);

  @override
  bool operator ==(Object other) =>
      other is ExchangeDefaultWalletAddressInvalidFailure &&
      other.network == network;

  @override
  int get hashCode =>
      Object.hash(ExchangeDefaultWalletAddressInvalidFailure, network);
}

/// The default wallet could not be saved.
final class ExchangeDefaultWalletSaveFailure extends ExchangeFailure {
  const ExchangeDefaultWalletSaveFailure();
}

/// The default wallet could not be removed.
final class ExchangeDefaultWalletDeleteFailure extends ExchangeFailure {
  const ExchangeDefaultWalletDeleteFailure();
}

final class ExchangeConsentRegistrationFailure extends ExchangeFailure {
  const ExchangeConsentRegistrationFailure([super.logMessage]);
}

final class ExchangeChatLoadMessagesFailure extends ExchangeFailure {
  const ExchangeChatLoadMessagesFailure([super.logMessage]);
}

final class ExchangeChatSendMessageFailure extends ExchangeFailure {
  const ExchangeChatSendMessageFailure([super.logMessage]);
}

final class ExchangeChatLoadAttachmentFailure extends ExchangeFailure {
  const ExchangeChatLoadAttachmentFailure([super.logMessage]);
}

/// The support chat needs a Bull Bitcoin account: the actionable signal is
/// "log in", not "retry".
final class ExchangeChatNotAuthenticatedFailure extends ExchangeFailure {
  const ExchangeChatNotAuthenticatedFailure([super.logMessage]);
}

/// The user tried to send an empty chat message.
final class ExchangeChatMessageEmptyFailure extends ExchangeFailure {
  const ExchangeChatMessageEmptyFailure();
}

/// A chat attachment came back without usable file data.
final class ExchangeChatAttachmentEmptyFailure extends ExchangeFailure {
  const ExchangeChatAttachmentEmptyFailure([super.logMessage]);
}

/// Picking images for a chat message failed.
final class ExchangeChatPickImagesFailure extends ExchangeFailure {
  const ExchangeChatPickImagesFailure([super.logMessage]);
}

/// Building or attaching the diagnostic logs failed.
final class ExchangeChatAttachLogsFailure extends ExchangeFailure {
  const ExchangeChatAttachLogsFailure([super.logMessage]);
}

enum ExchangeLimitOrderProblem {
  load,
  create,

  /// The create may have reached the exchange without a readable answer: the
  /// limit order may exist, so it is never offered again.
  createOutcomeUnknown,
  cancel,
  maximumActive,
  notFound,
  invalidAddress,
}

final class ExchangeLimitOrderFailure extends ExchangeFailure {
  final ExchangeLimitOrderProblem problem;

  const ExchangeLimitOrderFailure(this.problem, [super.logMessage]);
}

enum ExchangeFundingProblem {
  paymentOptionUnavailable,
  optionNotPermitted,
  sinpeNotRegistered,
  kycIncomplete,
  copRequestInvalid,
  sepaVirtualPaymentInactive,
  requestInvalid,
  noInstitutions,
}

final class ExchangeFundingFailure extends ExchangeFailure {
  final ExchangeFundingProblem problem;

  const ExchangeFundingFailure(this.problem, [super.logMessage]);
}

final class ExchangeVirtualIbanNotAvailableFailure extends ExchangeFailure {
  const ExchangeVirtualIbanNotAvailableFailure();
}

final class ExchangeEuResidencyRequiredFailure extends ExchangeFailure {
  const ExchangeEuResidencyRequiredFailure();
}

/// The unknown-write journal could not be read or written.
final class ExchangeJournalFailure extends ExchangeFailure {
  const ExchangeJournalFailure([super.logMessage]);
}

/// The picked destination gave no usable address: the app wallet is no
/// longer listed or gave no receive address.
final class ExchangeDestinationUnavailableFailure extends ExchangeFailure {
  const ExchangeDestinationUnavailableFailure([super.logMessage]);
}

/// The typed text is not an address the flow can pay out to.
final class ExchangeDestinationInvalidFailure extends ExchangeFailure {
  const ExchangeDestinationInvalidFailure([super.logMessage]);
}
