import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:flutter/widgets.dart';

extension BackupSettingsFailureL10n on BackupSettingsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BackupSettingsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    BackupSettingsVaultMismatchFailure() =>
      context.loc.bullVaultDescriptorMismatch,
    BackupSettingsNetworkFailure() => context.loc.dataBackupNetworkFailure,
    BackupSettingsDataMissingFailure() => context.loc.dataBackupMissing,
    BackupSettingsRecoveryIncompleteFailure() =>
      context.loc.dataBackupRecoveryIncomplete,
    BackupSettingsRateLimitedFailure(:final retryAt) =>
      context.loc.dataBackupRetryAt(retryAt.toLocal().toString()),
    BackupSettingsWordsUnavailableFailure() =>
      context.loc.dataBackupWordsUnavailable,
  };
}
