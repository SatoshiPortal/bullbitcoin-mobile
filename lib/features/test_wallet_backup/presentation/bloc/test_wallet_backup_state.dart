part of 'test_wallet_backup_bloc.dart';

@freezed
class VaultProvider with _$VaultProvider {
  const factory VaultProvider.googleDrive() = GoogleDrive;
  const factory VaultProvider.iCloud() = ICloud;
  const factory VaultProvider.fileSystem(String fileAsString) = FileSystem;
}

@freezed
class TestWalletBackupState with _$TestWalletBackupState {
  const factory TestWalletBackupState({
    @Default(false) bool isLoading,
    @Default('') String error,
    @Default(false) bool isSuccess,
    @Default(VaultProvider.googleDrive()) VaultProvider vaultProvider,
    @Default(BackupInfo.empty()) BackupInfo backupInfo,
  }) = _TestWalletBackupState;
}
