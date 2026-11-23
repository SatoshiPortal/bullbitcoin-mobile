import 'package:primitives/primitives.dart' show Failure;

/// Closed set of every failure the onboarding flow (create/recover default
/// wallets) surfaces to the user.
///
/// The host maps default-wallet and backup-verification failures at the
/// composition boundary. Presentation owns localized messages.
sealed class OnboardingFailure extends Failure {
  const OnboardingFailure([super.logMessage]);
}

/// The wallet-setup step (creating or recovering the default wallets)
/// failed.
final class OnboardingWalletSetupFailure extends OnboardingFailure {
  const OnboardingWalletSetupFailure();
}

/// The wallet itself was recovered successfully, but marking the physical
/// backup as verified failed afterwards — distinct from
/// [OnboardingWalletSetupFailure] so the user isn't told wallet setup failed
/// when it didn't.
final class OnboardingBackupVerificationFailure extends OnboardingFailure {
  const OnboardingBackupVerificationFailure();
}

/// The pre-recovery Bitcoin history scan failed.
final class OnboardingWalletScanFailure extends OnboardingFailure {
  const OnboardingWalletScanFailure();
}
