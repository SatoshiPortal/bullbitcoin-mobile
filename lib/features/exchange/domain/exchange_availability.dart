import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';

enum ExchangeAvailability {
  hidden,
  signInRequired,
  ready,
  unavailable;

  /// Account management and support authentication remain available when
  /// platform policy hides activation and trading.
  static bool canManageAccount(ExchangeAccess access) =>
      access is ExchangeAccessEnabled &&
      access.session == ExchangeAccessSession.signedIn;

  static bool canAuthenticate(ExchangeAccess access) =>
      access is ExchangeAccessEnabled &&
      access.session != ExchangeAccessSession.unreadable;

  static ExchangeAvailability resolve({
    required bool platformAllowed,
    required ExchangeAccess access,
  }) {
    if (!platformAllowed ||
        access is ExchangeAccessDisabled ||
        access is ExchangeAccessSignOutIncomplete) {
      return ExchangeAvailability.hidden;
    }
    return switch (access) {
      ExchangeAccessEnabled(session: ExchangeAccessSession.signedIn) =>
        ExchangeAvailability.ready,
      ExchangeAccessEnabled(session: ExchangeAccessSession.signedOut) =>
        ExchangeAvailability.signInRequired,
      _ => ExchangeAvailability.unavailable,
    };
  }
}
