import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the onboarding flow (create/recover default
/// wallets) surfaces to the user.
///
/// [CreateDefaultWalletsUsecase] (core/wallet) and the shared
/// `CompletePhysicalBackupVerificationUsecase` still throw — they are caught
/// at the boundary onboarding owns (its own use-cases in `domain/usecases/`)
/// and mapped here; the raw reason stays in the logs. `sealed` keeps this
/// closed (exhaustive switches; no foreign variants). Pure Dart — the
/// user-facing message lives in `presentation/onboarding_failure_l10n.dart`.
sealed class OnboardingFailure extends Failure {
  const OnboardingFailure([super.logMessage]);
}

/// The wallet-setup step (creating or recovering the default wallets)
/// failed — used by both the create and the recover flow, since both wrap
/// the same core [CreateDefaultWalletsUsecase].
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
