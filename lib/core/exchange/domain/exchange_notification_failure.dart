import 'package:bb_mobile/core/failures/failure.dart';

/// Failures of [ExchangeNotificationRepository], the push-notification socket.
///
/// The socket is best-effort — the exchange is fully usable without it — so
/// consumers routinely log these rather than surface them.
sealed class ExchangeNotificationFailure extends Failure {
  const ExchangeNotificationFailure([super.logMessage]);
}

/// The socket could not be opened or re-opened.
final class ExchangeNotificationConnectFailure
    extends ExchangeNotificationFailure {
  const ExchangeNotificationConnectFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI.
final class ExchangeNotificationUnexpectedFailure
    extends ExchangeNotificationFailure {
  const ExchangeNotificationUnexpectedFailure([super.logMessage]);
}
