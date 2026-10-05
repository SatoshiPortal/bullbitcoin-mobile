import 'package:bb_mobile/core/failures/failure.dart';

sealed class TestWalletBackupFailure extends Failure {
  const TestWalletBackupFailure([super.logMessage]);
}

/// The wallet list could not be read.
final class TestWalletBackupWalletsUnavailableFailure
    extends TestWalletBackupFailure {
  const TestWalletBackupWalletsUnavailableFailure([super.logMessage]);
}

/// The wallet list came back empty, so there is nothing to verify a backup
/// against. Distinct from [TestWalletBackupWalletsUnavailableFailure]: nothing failed,
/// there is simply no wallet.
final class TestWalletBackupNoWalletsFailure extends TestWalletBackupFailure {
  const TestWalletBackupNoWalletsFailure([super.logMessage]);
}

/// A verification was requested before a wallet had been selected.
final class TestWalletBackupNoWalletSelectedFailure
    extends TestWalletBackupFailure {
  const TestWalletBackupNoWalletSelectedFailure([super.logMessage]);
}

/// The seed for the selected wallet could not be read.
final class TestWalletBackupSeedUnavailableFailure
    extends TestWalletBackupFailure {
  const TestWalletBackupSeedUnavailableFailure([super.logMessage]);
}

/// The stored seed is not a mnemonic, so there is no phrase to show or
/// compare — a physical backup test does not apply to it.
final class TestWalletBackupSeedNotMnemonicFailure
    extends TestWalletBackupFailure {
  const TestWalletBackupSeedNotMnemonicFailure([super.logMessage]);
}

/// The words matched, but recording the successful verification failed. The
/// user did nothing wrong, and the test will simply be requested again.
final class TestWalletBackupCompletionFailure extends TestWalletBackupFailure {
  const TestWalletBackupCompletionFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class TestWalletBackupUnexpectedFailure extends TestWalletBackupFailure {
  const TestWalletBackupUnexpectedFailure([super.logMessage]);
}
