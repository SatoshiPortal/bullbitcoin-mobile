part of 'test_wallet_backup_bloc.dart';

@freezed
abstract class TestWalletBackupState with _$TestWalletBackupState {
  const factory TestWalletBackupState({
    @Default([]) List<String> mnemonic,
    @Default('') String passphrase,
    @Default([]) List<String> shuffledMnemonic,
    @Default([]) List<String> reorderedMnemonic,
    @Default([]) List<int> selectedMnemonicWords,
    TestWalletBackupFailure? failure,
    @Default([]) List<Wallet> wallets,
    @Default(null) Wallet? selectedWallet,
    @Default(false) bool isVerificationSaving,
    @Default(false) bool isVerificationComplete,
  }) = _TestWalletBackupState;
  const TestWalletBackupState._();
}
