import 'package:bb_mobile/core/failures/failure.dart';

sealed class AppUnlockFailure extends Failure {
  const AppUnlockFailure([super.logMessage]);
}

final class AppUnlockPinCheckFailure extends AppUnlockFailure {
  const AppUnlockPinCheckFailure([super.logMessage]);
}

final class AppUnlockKeychainLockedFailure extends AppUnlockFailure {
  const AppUnlockKeychainLockedFailure();
}

final class AppUnlockPinVerifyFailure extends AppUnlockFailure {
  const AppUnlockPinVerifyFailure([super.logMessage]);
}

/// Catch-all for unexpected storage errors. [logMessage] is for logs ONLY
/// and MUST never reach the UI.
final class AppUnlockUnexpectedFailure extends AppUnlockFailure {
  const AppUnlockUnexpectedFailure([super.logMessage]);
}
