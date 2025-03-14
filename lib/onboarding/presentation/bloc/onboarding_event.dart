part of 'onboarding_bloc.dart';

sealed class OnboardingEvent {
  const OnboardingEvent();
}

class OnboardingGoToRecoverStep extends OnboardingEvent {
  const OnboardingGoToRecoverStep();
}

class OnboardingGoBack extends OnboardingEvent {
  const OnboardingGoBack();
}

class OnboardingCreateNewWallet extends OnboardingEvent {
  const OnboardingCreateNewWallet();
}

class OnboardingRecoveryWordChanged extends OnboardingEvent {
  const OnboardingRecoveryWordChanged({
    required this.index,
    required this.word,
  });

  final int index;
  final String word;
}

class OnboardingRecoverWalletClicked extends OnboardingEvent {
  const OnboardingRecoverWalletClicked();
}
