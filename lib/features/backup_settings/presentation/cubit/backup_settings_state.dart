part of 'backup_settings_cubit.dart';

enum BackupSettingsStatus { initial, loading, success, error }

enum WalletBackupSettingsOperation {
  idle,
  saving,
  backingUp,
  deleting,
  recovering,
}

@freezed
sealed class BackupSettingsState with _$BackupSettingsState {
  factory BackupSettingsState({
    @Default(false) bool isDefaultPhysicalBackupTested,
    DateTime? lastPhysicalBackup,
    @Default(false) bool isDefaultEncryptedBackupTested,
    DateTime? lastEncryptedBackup,
    WalletBackupState? walletBackup,
    WalletBackupRecoveryOutcome? lastRecoveryOutcome,
    @Default(WalletBackupSettingsOperation.idle)
    WalletBackupSettingsOperation walletBackupOperation,
    @Default(BackupSettingsStatus.initial) BackupSettingsStatus status,
    BackupSettingsFailure? failure,
  }) = _BackupSettingsState;

  const BackupSettingsState._();

  bool get walletBackupBusy =>
      walletBackupOperation != WalletBackupSettingsOperation.idle;

  bool get canRetryRecovery =>
      !walletBackupBusy && (walletBackup?.recoveryBlocked ?? false);
}
