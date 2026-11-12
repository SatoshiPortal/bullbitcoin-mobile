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

/// A default wallet's metadata exists but the keystore, read in full, has no
/// seed under its fingerprint. Never a locked keystore: that one is
/// [AppStartupKeychainLockedFailure], transient, and waited out.
///
/// The way back is the user's backup: the failure screen offers to enter the
/// recovery phrase again, which is checked against [masterFingerprint].
final class AppStartupMissingDefaultSecretFailure extends AppStartupFailure {
  /// The wallet whose seed is gone. A fingerprint, never material.
  final String masterFingerprint;

  const AppStartupMissingDefaultSecretFailure(this.masterFingerprint)
    : super(masterFingerprint);
}

/// The recovery phrase entered to restore a missing default secret belongs to
/// another wallet.
final class AppStartupRestoreMismatchFailure extends AppStartupFailure {
  const AppStartupRestoreMismatchFailure([super.logMessage]);
}

/// The recovery phrase could not be stored again.
final class AppStartupRestoreFailure extends AppStartupFailure {
  const AppStartupRestoreFailure([super.logMessage]);
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
