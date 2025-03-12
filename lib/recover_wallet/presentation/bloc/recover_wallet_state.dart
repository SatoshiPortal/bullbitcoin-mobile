part of 'recover_wallet_bloc.dart';

enum RecoverWalletStatus { inProgress, success }

@freezed
sealed class RecoverWalletState implements _$RecoverWalletState {
  const factory RecoverWalletState({
    @Default(false) bool fromOnboarding,
    @Default(RecoverWalletStatus.inProgress) RecoverWalletStatus status,
    @Default(12) int wordsCount,
    @Default({}) Map<int, String> validWords,
    @Default({}) Map<int, List<String>> hintWords,
    @Default('') String passphrase,
    @Default(ScriptType.bip84) ScriptType scriptType,
    @Default('') String label,
    @Default(false) bool isConfirming,
    Wallet? recoveredWallet,
    @Default(null) Object? error,
  }) = _RecoverWalletState;
  const RecoverWalletState._();

  bool get hasAllValidWords => validWords.length == wordsCount && !isConfirming;
}
