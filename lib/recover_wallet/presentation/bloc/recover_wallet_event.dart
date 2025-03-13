part of 'recover_wallet_bloc.dart';

sealed class RecoverWalletEvent {
  const RecoverWalletEvent();
}

class RecoverWalletWordsCountChanged extends RecoverWalletEvent {
  final int wordsCount;

  const RecoverWalletWordsCountChanged({required this.wordsCount});
}

class RecoverWalletWordChanged extends RecoverWalletEvent {
  final int index;
  final String word;
  final bool tapped;

  const RecoverWalletWordChanged({
    required this.index,
    required this.word,
    required this.tapped,
  });
}

class RecoverWalletPassphraseChanged extends RecoverWalletEvent {
  final String passphrase;

  const RecoverWalletPassphraseChanged(this.passphrase);
}

class RecoverWalletLabelChanged extends RecoverWalletEvent {
  final String label;

  const RecoverWalletLabelChanged(this.label);
}

class RecoverWalletScriptTypeChanged extends RecoverWalletEvent {
  final ScriptType scriptType;

  const RecoverWalletScriptTypeChanged(this.scriptType);
}

class RecoverWalletConfirmed extends RecoverWalletEvent {
  const RecoverWalletConfirmed();
}

class ClearUntappedWords extends RecoverWalletEvent {
  const ClearUntappedWords();
}

class RecoverFromOnboarding extends RecoverWalletEvent {
  const RecoverFromOnboarding();
}

class ImportTestableWallet extends RecoverWalletEvent {
  final bool useTestWallet;
  const ImportTestableWallet({required this.useTestWallet});
}
