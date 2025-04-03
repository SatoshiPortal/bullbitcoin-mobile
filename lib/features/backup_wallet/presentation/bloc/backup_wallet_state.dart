part of 'backup_wallet_bloc.dart';

@freezed
sealed class BackupWalletStatus with _$BackupWalletStatus {
  const factory BackupWalletStatus.initial() = _Initial;
  const factory BackupWalletStatus.loading() = _Loading;
  const factory BackupWalletStatus.success() = _Success;
  const factory BackupWalletStatus.failure(String message) = _Failure;
}

@freezed
sealed class BackupWalletState with _$BackupWalletState {
  const factory BackupWalletState({
    @Default(VaultProvider.googleDrive()) VaultProvider vaultProvider,
    @Default('') String backupFile,
    @Default(BackupWalletStatus.initial()) BackupWalletStatus status,
    @Default(false) bool transitioning,
  }) = _BackupWalletState;
  const BackupWalletState._();
}
