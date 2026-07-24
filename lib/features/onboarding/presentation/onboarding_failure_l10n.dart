import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [OnboardingFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
extension OnboardingFailureL10n on OnboardingFailure {
  String toTranslated(BuildContext context) => switch (this) {
    OnboardingWalletSetupFailure() => context.loc.walletSetupErrorTryAgain,
    OnboardingBackupVerificationFailure() =>
      context.loc.onboardingBackupVerificationError,
  };
}
