import 'package:primitives/primitives.dart' show Failure;

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

/// A server HTTP 401 rejected the active request's credential.
/// Only this failure may expire a session automatically.
final class ExchangeSessionRejectedFailure extends ExchangeFailure {
  const ExchangeSessionRejectedFailure([super.logMessage]);
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

/// Language, currency, notification or DCA preferences could not be saved.
final class ExchangePreferencesSaveFailure extends ExchangeFailure {
  const ExchangePreferencesSaveFailure([super.logMessage]);
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

/// A legacy stored credential could not be decoded.
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

final class ExchangeStatisticsUnavailableFailure extends ExchangeFailure {
  const ExchangeStatisticsUnavailableFailure([super.logMessage]);
}

final class ExchangeDocumentUploadFailure extends ExchangeFailure {
  const ExchangeDocumentUploadFailure([super.logMessage]);
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

enum ExchangeLimitOrderProblem {
  load,
  create,
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
