part of 'backup_settings_cubit.dart';

@freezed
class BackupSettingsState with _$BackupSettingsState {
  factory BackupSettingsState({
    @Default(false) bool isDefaultPhysicalBackupTested,
    @Default(false) bool isDefaultEncryptedBackupTested,
    @Default(false) bool loading,
  }) = _BackupSettingsState;
}
