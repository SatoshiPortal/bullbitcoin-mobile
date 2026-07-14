import 'package:bb_mobile/core/failures/failure.dart';

sealed class OnboardingFailure extends Failure {
  const OnboardingFailure([super.logMessage]);
}

final class OnboardingUnexpectedFailure extends OnboardingFailure {
  const OnboardingUnexpectedFailure([super.logMessage]);
}
