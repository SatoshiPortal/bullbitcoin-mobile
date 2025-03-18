part of 'backup_wallet_bloc.dart';

@freezed
sealed class BackupWalletStatus with _$BackupWalletStatus {
  const factory BackupWalletStatus.initial() = _Initial;
  const factory BackupWalletStatus.loading() = _Loading;
  const factory BackupWalletStatus.success() = _Success;
  const factory BackupWalletStatus.failure(String? message) = _Failure;
}

@freezed
sealed class BackupProvider with _$BackupProvider {
  const factory BackupProvider.googleDrive() = _GoogleDrive;
  const factory BackupProvider.iCloud() = _ICloud;
  const factory BackupProvider.fileSystem(String filePath) = _FileSystem;
}

@freezed
sealed class BackupWalletState with _$BackupWalletState {
  const factory BackupWalletState({
    @Default(BackupProvider.googleDrive()) BackupProvider backupProvider,
    @Default('') String encryted,
    @Default(BackupWalletStatus.initial) BackupWalletStatus status,
  }) = _BackupWalletState;

  factory BackupWalletState.error(String error) => BackupWalletState(
        status: BackupWalletStatus.failure(error),
      );
}
