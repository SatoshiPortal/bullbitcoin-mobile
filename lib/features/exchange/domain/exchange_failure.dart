import 'package:bb_mobile/core/failures/failure.dart';

/// Every user-facing failure of the exchange feature, as one closed family.
/// Flutter-free: translation lives in `presentation/exchange_failure_l10n.dart`.
///
/// `logMessage` reaches logs and Sentry only. It MUST never be rendered — the
/// exchange API and the legacy `BullException` chain both carry operator-facing
/// English that is not safe to put in front of a user.
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

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class ExchangeUnexpectedFailure extends ExchangeFailure {
  const ExchangeUnexpectedFailure([super.logMessage]);
}
