part of 'backup_wallet_bloc.dart';

enum LoadingType {
  general,
  googleSignIn,
}

@freezed
sealed class BackupWalletStatus with _$BackupWalletStatus {
  const factory BackupWalletStatus.initial() = _Initial;
  const factory BackupWalletStatus.loading(LoadingType type) = _Loading;
  const factory BackupWalletStatus.success() = _Success;
  const factory BackupWalletStatus.failure(String message) = _Failure;
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
    @Default('') String backupFile,
    @Default(BackupWalletStatus.initial()) BackupWalletStatus status,
  }) = _BackupWalletState;
  const BackupWalletState._();
}
