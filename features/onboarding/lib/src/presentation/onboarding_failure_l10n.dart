import 'package:onboarding/src/onboarding_l10n.dart';
import 'package:onboarding/src/domain/onboarding_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [OnboardingFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
extension OnboardingFailureL10n on OnboardingFailure {
  String toTranslated(BuildContext context) => switch (this) {
    OnboardingWalletScanFailure() => context.loc.oopsSomethingWentWrong,
    OnboardingWalletSetupFailure() => context.loc.walletSetupErrorTryAgain,
    OnboardingBackupVerificationFailure() =>
      context.loc.onboardingBackupVerificationError,
  };
}
