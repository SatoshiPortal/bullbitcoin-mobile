part of 'test_wallet_backup_bloc.dart';

enum BackupVerificationStatus { idle, success, failure }

@freezed
abstract class TestWalletBackupState with _$TestWalletBackupState {
  const factory TestWalletBackupState({
    TestWalletBackupFailure? failure,
    @Default([]) List<Wallet> wallets,
    @Default(null) Wallet? selectedWallet,
    @Default(BackupVerificationStatus.idle)
    BackupVerificationStatus verificationStatus,
  }) = _TestWalletBackupState;
  const TestWalletBackupState._();
}
