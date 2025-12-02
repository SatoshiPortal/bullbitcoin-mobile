part of 'test_wallet_backup_bloc.dart';

@freezed
abstract class TestWalletBackupState with _$TestWalletBackupState {
  const factory TestWalletBackupState({
    @Default([]) List<String> mnemonic,
    @Default('') String passphrase,
    @Default([]) List<String> shuffledMnemonic,
    @Default([]) List<String> reorderedMnemonic,
    @Default([]) List<int> selectedMnemonicWords,
    @Default('') String statusError,
    @Default([]) List<Wallet> wallets,
    @Default(null) Wallet? selectedWallet,
  }) = _TestWalletBackupState;
  const TestWalletBackupState._();
}
