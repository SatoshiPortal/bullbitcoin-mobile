part of 'backup_settings_cubit.dart';

enum BackupSettingsStatus { initial, loading, success, error }

@freezed
sealed class BackupSettingsState with _$BackupSettingsState {
  factory BackupSettingsState({
    @Default(false) bool isDefaultPhysicalBackupTested,
    DateTime? lastPhysicalBackup,
    @Default(false) bool hasEncryptedBackup,
    @Default(false) bool isDefaultEncryptedBackupTested,
    @Default(BackupSettingsStatus.initial) BackupSettingsStatus status,
    BackupSettingsFailure? failure,
  }) = _BackupSettingsState;
}
