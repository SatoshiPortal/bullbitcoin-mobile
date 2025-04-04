part of 'test_wallet_backup_bloc.dart';

enum TestWalletBackupStatus {
  none,
  loading,
  success,
  error,
}

@freezed
class TestWalletBackupState with _$TestWalletBackupState {
  const factory TestWalletBackupState({
    @Default(TestWalletBackupStatus.none) TestWalletBackupStatus status,
    @Default(VaultProvider.googleDrive()) VaultProvider vaultProvider,
    @Default(BackupInfo.empty()) BackupInfo backupInfo,
    @Default(false) bool transitioning,
    @Default('') String statusError,
  }) = _TestWalletBackupState;
}
