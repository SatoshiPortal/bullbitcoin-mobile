import 'package:bb_mobile/core/failures/failure.dart';

/// Failures of [ExchangeUserRepository], the account side of the exchange API.
///
/// `logMessage` reaches logs and Sentry only. Consuming features lift these
/// into their own family before anything is shown to a user.
sealed class ExchangeUserFailure extends Failure {
  const ExchangeUserFailure([super.logMessage]);
}

/// No API key is stored, so there is no account to act on — the actionable
/// signal is "log in", not "retry".
final class ExchangeUserNotAuthenticatedFailure extends ExchangeUserFailure {
  const ExchangeUserNotAuthenticatedFailure([super.logMessage]);
}

/// The account could not be read.
final class ExchangeUserSummaryUnavailableFailure extends ExchangeUserFailure {
  const ExchangeUserSummaryUnavailableFailure([super.logMessage]);
}

/// Saving language, currency, notification or DCA preferences failed.
final class ExchangeUserPreferencesSaveFailure extends ExchangeUserFailure {
  const ExchangeUserPreferencesSaveFailure([super.logMessage]);
}

/// The announcement list could not be read.
final class ExchangeUserAnnouncementsUnavailableFailure
    extends ExchangeUserFailure {
  const ExchangeUserAnnouncementsUnavailableFailure([super.logMessage]);
}

/// Recording the scam-warning consent failed.
final class ExchangeUserConsentRegistrationFailure extends ExchangeUserFailure {
  const ExchangeUserConsentRegistrationFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI.
final class ExchangeUserUnexpectedFailure extends ExchangeUserFailure {
  const ExchangeUserUnexpectedFailure([super.logMessage]);
}
