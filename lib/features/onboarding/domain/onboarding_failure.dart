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

final class OnboardingWalletCreationFailure extends OnboardingFailure {
  const OnboardingWalletCreationFailure();
}

final class OnboardingBackupVerificationFailure extends OnboardingFailure {
  const OnboardingBackupVerificationFailure();
}
