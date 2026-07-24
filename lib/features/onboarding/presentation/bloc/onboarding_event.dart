part of 'onboarding_bloc.dart';

sealed class OnboardingEvent {
  const OnboardingEvent();
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
  const OnboardingRecoverWalletClicked({required this.mnemonic});

  final RecoveryMnemonic mnemonic;
}

/// Dispatched by `OnboardingPhysicalRecovery` once `WalletBirthdayPicker`
/// (shown after `state.needsBitcoinBirthdaySelection` turns true) settles —
/// [checkpoint] is the resolved value, or `null` if the user backed out of
/// the picker entirely. See `OnboardingBloc._onBitcoinBirthdayResolved`.
class OnboardingBitcoinBirthdayResolved extends OnboardingEvent {
  const OnboardingBitcoinBirthdayResolved({this.checkpoint});

  final WalletBirthdayCheckpoint? checkpoint;
}
