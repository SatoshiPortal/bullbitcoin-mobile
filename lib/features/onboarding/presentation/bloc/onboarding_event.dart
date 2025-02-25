part of 'onboarding_bloc.dart';

sealed class OnboardingEvent {
  const OnboardingEvent();
}

class OnboardingWalletCreated extends OnboardingEvent {
  const OnboardingWalletCreated();
}
