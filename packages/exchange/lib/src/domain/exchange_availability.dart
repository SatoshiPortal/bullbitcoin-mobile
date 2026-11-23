import 'exchange_access.dart';

enum ExchangePlatform { ios, other }

enum ExchangeAvailability {
  hidden,
  signInRequired,
  ready,
  unavailable;

  static bool platformAllowed(
    ExchangePlatform platform, {
    bool isSuperuser = false,
  }) => platform != ExchangePlatform.ios || isSuperuser;

  /// Account management and support authentication remain available when
  /// platform policy hides activation and trading.
  static bool canManageAccount(ExchangeAccess access) => access.isSignedIn;

  /// Whether a web sign-in can be offered: the exchange is on and its
  /// credential store is readable.
  static bool canAuthenticate(ExchangeAccess access) => switch (access) {
    ExchangeAccessSignedOut() ||
    ExchangeAccessSignedIn() ||
    ExchangeAccessExpiring() => true,
    ExchangeAccessResolving() ||
    ExchangeAccessUnreadable() ||
    ExchangeAccessDisabled() ||
    ExchangeAccessSignOutIncomplete() ||
    ExchangeAccessCredentialUnreadable() => false,
  };

  static ExchangeAvailability resolve({
    required bool platformAllowed,
    required ExchangeAccess access,
  }) {
    if (!platformAllowed) return ExchangeAvailability.hidden;
    return switch (access) {
      ExchangeAccessDisabled() ||
      ExchangeAccessSignOutIncomplete() => ExchangeAvailability.hidden,
      ExchangeAccessSignedIn() => ExchangeAvailability.ready,
      ExchangeAccessSignedOut() => ExchangeAvailability.signInRequired,
      ExchangeAccessResolving() ||
      ExchangeAccessUnreadable() ||
      ExchangeAccessExpiring() ||
      ExchangeAccessCredentialUnreadable() => ExchangeAvailability.unavailable,
    };
  }
}
