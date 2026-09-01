import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

/// Translates the backup feature's failures into the states the settings
/// screen can explain.
///
/// The switch is exhaustive on purpose: a new [WalletBackupFailure] has to be
/// given a user meaning here rather than silently collapsing into
/// "something went wrong" (spec F17, 21.2).
BackupSettingsFailure mapWalletBackupFailure(
  WalletBackupFailure failure,
) => switch (failure) {
  // Availability. Local work stays pending; nothing about it is invalid.
  WalletBackupRemoteUnavailableFailure() ||
  WalletBackupRateLimitedFailure() => const BackupSettingsUnavailableFailure(),
  WalletBackupDisabledFailure() => const BackupSettingsDisabledFailure(),
  WalletBackupInvalidServerOriginFailure() =>
    const BackupSettingsInvalidServerFailure(),
  WalletBackupUnsupportedEnvelopeVersionFailure() =>
    const BackupSettingsUpdateRequiredFailure(),
  WalletBackupParentFingerprintMismatchFailure() =>
    const BackupSettingsSeedMismatchFailure(),
  WalletBackupInvalidEnvelopeFailure() ||
  WalletBackupEncryptionFailure() ||
  WalletBackupManifestFailure() ||
  WalletBackupDefinitionsFailure() => const BackupSettingsInvalidFileFailure(),
  WalletBackupSigningFailure() ||
  WalletBackupInvalidRemoteFailure() ||
  WalletBackupRemoteRejectedFailure() =>
    const BackupSettingsUnverifiedFailure(),
  WalletBackupTooLargeFailure() => const BackupSettingsFileTooLargeFailure(),
  WalletBackupHeadConflictFailure() =>
    const BackupSettingsHeadConflictFailure(),
  WalletBackupStorageFailure() => const BackupSettingsStorageFailure(),
  WalletBackupRecoveryBlockedFailure() =>
    const BackupSettingsRecoveryNeedsAttentionFailure(),
  WalletBackupKeyDerivationFailure() ||
  WalletBackupWalletUnavailableFailure() ||
  WalletBackupConfirmationRequiredFailure() ||
  WalletBackupDeleteRequiresDisabledFailure() ||
  WalletBackupUnexpectedFailure() => BackupSettingsUnexpectedFailure(
    failure.runtimeType.toString(),
  ),
};

/// The user meaning of a finished recovery, or null when it finished cleanly.
///
/// A recovery that only got part way is never reported as success (spec 21.1).
BackupSettingsFailure? mapWalletBackupRecoveryStatus(
  WalletBackupRecoveryStatus status,
) => switch (status) {
  WalletBackupRecoveryStatus.restored ||
  WalletBackupRecoveryStatus.noBackup => null,
  WalletBackupRecoveryStatus.partiallyRestored ||
  WalletBackupRecoveryStatus.comparisonStale =>
    const BackupSettingsRecoveryNeedsAttentionFailure(),
  WalletBackupRecoveryStatus.unavailable ||
  WalletBackupRecoveryStatus.timedOut =>
    const BackupSettingsUnavailableFailure(),
  WalletBackupRecoveryStatus.newerVersion =>
    const BackupSettingsUpdateRequiredFailure(),
  WalletBackupRecoveryStatus.conflict =>
    const BackupSettingsHeadConflictFailure(),
  WalletBackupRecoveryStatus.invalid =>
    const BackupSettingsInvalidFileFailure(),
  WalletBackupRecoveryStatus.localFailure =>
    const BackupSettingsStorageFailure(),
};
