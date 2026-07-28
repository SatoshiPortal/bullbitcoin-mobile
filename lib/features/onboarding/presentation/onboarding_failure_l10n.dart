import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:flutter/widgets.dart';

extension OnboardingFailureL10n on OnboardingFailure {
  String toTranslated(BuildContext context) => switch (this) {
    OnboardingUnexpectedFailure() => context.loc.walletSetupErrorTryAgain,
    OnboardingBackupVerificationPersistenceFailure() =>
      context.loc.onboardingBackupVerificationSaveFailed,
  };
}
