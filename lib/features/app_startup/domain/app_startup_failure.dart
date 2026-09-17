import 'package:bb_mobile/core/failures/failure.dart';

/// Deliberately has no `AppStartupUnexpectedFailure` catch-all. Every
/// collaborator this feature calls is wrapped by one of its own use-cases, so
/// there is no unmapped path left for one to land on and an unconstructed
/// variant would just be dead code. A new startup step gets its own variant
/// here — not an untyped escape hatch on the state.
sealed class AppStartupFailure extends Failure {
  const AppStartupFailure([super.logMessage]);
}

final class AppStartupKeychainLockedFailure extends AppStartupFailure {
  const AppStartupKeychainLockedFailure([super.logMessage]);
}

/// The default wallets could not be read, or their seeds are missing.
final class AppStartupWalletCheckFailure extends AppStartupFailure {
  const AppStartupWalletCheckFailure([super.logMessage]);
}

/// Whether this is a pre-v5 install could not be determined.
final class AppStartupLegacyCheckFailure extends AppStartupFailure {
  const AppStartupLegacyCheckFailure([super.logMessage]);
}

/// The legacy seeds could not be enumerated for the backup screen.
final class AppStartupLegacySeedsFailure extends AppStartupFailure {
  const AppStartupLegacySeedsFailure([super.logMessage]);
}

/// Clearing data left behind by a previous install failed.
final class AppStartupResetFailure extends AppStartupFailure {
  const AppStartupResetFailure([super.logMessage]);
}

/// The PIN state could not be read. Lifted from the app_unlock feature's
/// failure at the boundary, so this feature never holds a foreign type.
final class AppStartupPinCheckFailure extends AppStartupFailure {
  const AppStartupPinCheckFailure([super.logMessage]);
}
