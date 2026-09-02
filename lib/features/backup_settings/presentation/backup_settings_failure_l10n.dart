import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:flutter/widgets.dart';

extension BackupSettingsFailureL10n on BackupSettingsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BackupSettingsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    BackupSettingsUnavailableFailure() =>
      context.loc.walletBackupSettingsUnavailable,
    BackupSettingsDisabledFailure() => context.loc.walletBackupSettingsDisabled,
    BackupSettingsUpdateRequiredFailure() =>
      context.loc.walletBackupSettingsUpdateRequired,
    BackupSettingsInvalidServerFailure() =>
      context.loc.walletBackupSettingsInvalidServer,
    BackupSettingsFileReadFailure() => context.loc.walletBackupFileReadFailure,
    BackupSettingsFileSaveFailure() => context.loc.walletBackupFileSaveFailure,
    BackupSettingsFileTooLargeFailure() => context.loc.walletBackupFileTooLarge,
    BackupSettingsInvalidFileFailure() => context.loc.walletBackupFileInvalid,
    BackupSettingsSeedMismatchFailure() =>
      context.loc.walletBackupSettingsSeedMismatch,
    BackupSettingsUnverifiedFailure() =>
      context.loc.walletBackupSettingsUnverified,
    BackupSettingsHeadConflictFailure() =>
      context.loc.walletBackupSettingsHeadConflict,
    BackupSettingsStorageFailure() =>
      context.loc.walletBackupSettingsStorageFailure,
    BackupSettingsRecoveryNeedsAttentionFailure() =>
      context.loc.walletBackupSettingsRecoveryBlocked,
  };
}
