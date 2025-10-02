part of 'backup_wallet_bloc.dart';

enum BackupWalletStatus { none, loading, success, error }

@freezed
sealed class BackupWalletState with _$BackupWalletState {
  const factory BackupWalletState({
    @Default(VaultProvider.googleDrive) VaultProvider vaultProvider,
    @Default(null) EncryptedVault? vault,
    @Default(BackupWalletStatus.none) BackupWalletStatus status,
    @Default(false) bool transitioning,
    @Default('') String statusError,
  }) = _BackupWalletState;
  const BackupWalletState._();
}
