import 'package:bb_mobile/core/failures/failure.dart';

/// Failures of [ExchangeApiKeyRepository], the stored-session side of the
/// exchange API.
///
/// `logMessage` reaches logs and Sentry only, and must stay free of the key
/// material these operations handle.
sealed class ExchangeApiKeyFailure extends Failure {
  const ExchangeApiKeyFailure([super.logMessage]);
}

/// The stored credential could not be read, including a locked keychain.
final class ExchangeApiKeyReadFailure extends ExchangeApiKeyFailure {
  const ExchangeApiKeyReadFailure([super.logMessage]);
}

/// The stored value cannot supply an authentication credential.
final class ExchangeApiKeyInvalidFailure extends ExchangeApiKeyFailure {
  const ExchangeApiKeyInvalidFailure([super.logMessage]);
}

/// The API key could not be stored, so the session would not survive.
final class ExchangeApiKeySaveFailure extends ExchangeApiKeyFailure {
  const ExchangeApiKeySaveFailure([super.logMessage]);
}

/// The API key could not be removed, so a sign-out may be incomplete.
final class ExchangeApiKeyDeleteFailure extends ExchangeApiKeyFailure {
  const ExchangeApiKeyDeleteFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI.
final class ExchangeApiKeyUnexpectedFailure extends ExchangeApiKeyFailure {
  const ExchangeApiKeyUnexpectedFailure([super.logMessage]);
}
