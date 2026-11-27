import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

import 'exchange_auth_state.dart';

@immutable
sealed class ExchangeAuthEvent {
  const ExchangeAuthEvent();
}

final class AuthConfigLoaded extends ExchangeAuthEvent {
  final ExchangeAuthConfig config;

  const AuthConfigLoaded(this.config);
}

final class AuthConfigUnavailable extends ExchangeAuthEvent {
  final ExchangeFailure failure;

  const AuthConfigUnavailable(this.failure);
}

final class AuthRetryRequested extends ExchangeAuthEvent {
  const AuthRetryRequested();
}

/// The WebView reached a page with a web session cookie.
final class AuthWebSessionSeen extends ExchangeAuthEvent {
  const AuthWebSessionSeen();
}

final class AuthKeyStored extends ExchangeAuthEvent {
  const AuthKeyStored();
}

/// The web session is not ready for a key yet; keep browsing.
final class AuthKeyDeferred extends ExchangeAuthEvent {
  const AuthKeyDeferred();
}

final class AuthKeyNotStored extends ExchangeAuthEvent {
  final ExchangeFailure failure;

  const AuthKeyNotStored(this.failure);
}

final class AuthErrorAcknowledged extends ExchangeAuthEvent {
  const AuthErrorAcknowledged();
}

/// Back, the close button or the site's "Back to App".
final class AuthCloseRequested extends ExchangeAuthEvent {
  const AuthCloseRequested();
}
