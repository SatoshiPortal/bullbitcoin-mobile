part of 'backup_settings_cubit.dart';

@freezed
sealed class BackupSettingsState with _$BackupSettingsState {
  factory BackupSettingsState({
    WalletBackupState? walletBackup,
    WalletBackupImportComparison? fileComparison,
    WalletBackupRecoveryResult? fileRecoveryResult,
    @Default(false) bool fileExportReady,
    WalletBackupContents? contents,
    @Default(false) bool contentsLoading,
    @Default(false) bool walletBackupBusy,
    BackupSettingsFailure? failure,
  }) = _BackupSettingsState;

  const BackupSettingsState._();

  bool get canRetryRecovery =>
      !walletBackupBusy && (walletBackup?.recoveryBlocked ?? false);
}
