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

  const RecoverWalletWordChanged({
    required this.index,
    required this.word,
  });
}

class RecoverWalletConfirmed extends RecoverWalletEvent {
  const RecoverWalletConfirmed();
}
