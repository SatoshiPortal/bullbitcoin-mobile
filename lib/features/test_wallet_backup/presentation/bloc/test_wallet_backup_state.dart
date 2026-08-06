part of 'test_wallet_backup_bloc.dart';

enum BackupVerificationStatus { idle, success, failure }

@freezed
abstract class TestWalletBackupState with _$TestWalletBackupState {
  const factory TestWalletBackupState({
    @Default('') String statusError,
    @Default([]) List<Wallet> wallets,
    @Default(null) Wallet? selectedWallet,
    @Default(BackupVerificationStatus.idle)
    BackupVerificationStatus verificationStatus,
  }) = _TestWalletBackupState;
  const TestWalletBackupState._();
}
