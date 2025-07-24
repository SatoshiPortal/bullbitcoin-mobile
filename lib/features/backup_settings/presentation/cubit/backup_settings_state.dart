part of 'backup_settings_cubit.dart';

enum BackupSettingsStatus {
  initial,
  loading,
  success,
  error,
  viewingKey,
  exporting,
}

@freezed
sealed class BackupSettingsState with _$BackupSettingsState {
  factory BackupSettingsState({
    @Default(false) bool isDefaultPhysicalBackupTested,
    DateTime? lastPhysicalBackup,
    @Default(false) bool isDefaultEncryptedBackupTested,
    DateTime? lastEncryptedBackup,
    @Default(BackupSettingsStatus.initial) BackupSettingsStatus status,
    String? downloadedBackupFile,
    String? selectedBackupFile,
    String? derivedBackupKey,
    Object? error,
  }) = _BackupSettingsState;
}
