import 'package:primitives/primitives.dart' show Failure;

sealed class AccessFailure extends Failure {
  const AccessFailure([super.logMessage]);
}

final class AccessPinCheckFailure extends AccessFailure {
  const AccessPinCheckFailure([super.logMessage]);
}

final class AccessUnlockKeychainLockedFailure extends AccessFailure {
  const AccessUnlockKeychainLockedFailure();
}

final class AccessPinVerifyFailure extends AccessFailure {
  const AccessPinVerifyFailure([super.logMessage]);
}

/// Catch-all for unexpected storage errors. [logMessage] is for logs ONLY
/// and MUST never reach the UI.
final class AccessUnlockUnexpectedFailure extends AccessFailure {
  const AccessUnlockUnexpectedFailure([super.logMessage]);
}

final class AccessPinSaveFailure extends AccessFailure {
  const AccessPinSaveFailure();
}

final class AccessPinDeleteFailure extends AccessFailure {
  const AccessPinDeleteFailure();
}

final class AccessPinNotSetFailure extends AccessFailure {
  const AccessPinNotSetFailure();
}

final class AccessPinSettingsKeychainLockedFailure extends AccessFailure {
  const AccessPinSettingsKeychainLockedFailure();
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class AccessPinSettingsUnexpectedFailure extends AccessFailure {
  const AccessPinSettingsUnexpectedFailure([super.logMessage]);
}
