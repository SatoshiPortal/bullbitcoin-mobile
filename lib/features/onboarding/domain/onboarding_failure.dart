import 'package:primitives/primitives.dart' show Failure;

/// Closed set of every failure the onboarding flow (create/recover default
/// wallets) surfaces to the user.
///
/// Default-wallet failures are translated here; backup verification still
/// throws and is caught by the recovery use case. Presentation owns messages.
sealed class OnboardingFailure extends Failure {
  const OnboardingFailure([super.logMessage]);
}

/// The wallet-setup step (creating or recovering the default wallets)
/// failed — used by both the create and the recover flow, since both wrap
/// the same [CreateDefaultWalletsUsecase].
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
