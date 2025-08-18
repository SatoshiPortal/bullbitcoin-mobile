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

  final ({
    List<String> words,
    String passphrase,
    String label,
    bip39.Language language,
  })
  mnemonic;
}

class SelectGoogleDriveRecovery extends OnboardingEvent {
  const SelectGoogleDriveRecovery();
}

class SelectFileSystemRecovery extends OnboardingEvent {
  const SelectFileSystemRecovery();
}

class StartWalletRecovery extends OnboardingEvent {
  const StartWalletRecovery({
    required this.backupKey,
    required this.backupFile,
  });
  final String backupKey;
  final String backupFile;
}

class StartTransitioning extends OnboardingEvent {
  const StartTransitioning();
}

class EndTransitioning extends OnboardingEvent {
  const EndTransitioning();
}
