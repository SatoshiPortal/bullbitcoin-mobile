part of 'backup_settings_cubit.dart';

enum BackupSettingsStatus { initial, loading, success, error }

enum WalletMetadataBackupActionStatus {
  idle,
  saved,
  unchanged,
  notReady,
  deleted,
  failed,
}

@freezed
sealed class BackupSettingsState with _$BackupSettingsState {
  factory BackupSettingsState({
    @Default(false) bool isDefaultPhysicalBackupTested,
    DateTime? lastPhysicalBackup,
    @Default(false) bool isDefaultEncryptedBackupTested,
    DateTime? lastEncryptedBackup,
    @Default(BackupSettingsStatus.initial) BackupSettingsStatus status,
    BackupSettingsFailure? failure,
    @Default(false) bool metadataBackupEnabled,
    @Default(false) bool metadataBackupDirty,
    @Default(false) bool metadataBackupBlocked,
    @Default(false) bool metadataBackupHasRemote,
    DateTime? metadataBackupLastVerifiedAt,
    @Default(false) bool metadataBackupBusy,
    @Default(WalletMetadataBackupActionStatus.idle)
    WalletMetadataBackupActionStatus metadataActionStatus,
  }) = _BackupSettingsState;
}
