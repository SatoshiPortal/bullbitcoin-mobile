import 'dart:io' show Platform;

import 'exchange_access.dart';

enum ExchangePlatform {
  ios,
  other;

  static ExchangePlatform get current =>
      Platform.isIOS ? ExchangePlatform.ios : ExchangePlatform.other;

  /// The one platform restriction: on iOS without superuser the exchange
  /// sends the user to the website. Every other platform is unrestricted.
  bool websiteOnly({required bool isSuperuser}) => switch (this) {
    ExchangePlatform.ios => !isSuperuser,
    ExchangePlatform.other => false,
  };
}

enum ExchangeAvailability {
  /// The exchange is off on this device, or a sign-out is still finishing.
  hidden,

  /// The platform restriction applies: use the website.
  websiteOnly,
  signInRequired,
  ready,
  unavailable;

  static bool platformAllowed(
    ExchangePlatform platform, {
    bool isSuperuser = false,
  }) => !platform.websiteOnly(isSuperuser: isSuperuser);

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
    if (!platformAllowed) return ExchangeAvailability.websiteOnly;
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
