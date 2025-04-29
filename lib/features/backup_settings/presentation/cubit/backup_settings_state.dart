part of 'backup_settings_cubit.dart';

@freezed
sealed class BackupSettingsState with _$BackupSettingsState {
  factory BackupSettingsState({
    @Default(false) bool isDefaultPhysicalBackupTested,
    DateTime? lastPhysicalBackup,
    @Default(false) bool isDefaultEncryptedBackupTested,
    DateTime? lastEncryptedBackup,
    @Default(false) bool loading,
  }) = _BackupSettingsState;
}
