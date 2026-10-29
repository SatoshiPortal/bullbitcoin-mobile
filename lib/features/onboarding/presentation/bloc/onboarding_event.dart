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
  const OnboardingRecoverWalletClicked({
    required this.mnemonic,
    this.birthday,
    this.bitcoinSyncSource = BitcoinSyncSource.electrum,
  });

  final WalletBirthday? birthday;
  final BitcoinSyncSource bitcoinSyncSource;

  final ({
    List<String> words,
    String passphrase,
    String label,
    bip39.Language language,
  })
  mnemonic;
}
