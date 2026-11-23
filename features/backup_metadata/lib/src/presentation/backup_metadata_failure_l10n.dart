import '../domain/backup_metadata_failure.dart';

/// Message identifiers until the presentation lane supplies its localizations.
extension BackupMetadataFailureL10n on BackupMetadataFailure {
  String get messageKey => switch (this) {
    BackupMetadataNotReadyFailure() => 'backupMetadataNotReady',
    BackupMetadataStalePlanFailure() => 'backupMetadataStalePlan',
    BackupMetadataTooLargeFailure() => 'backupMetadataTooLarge',
    BackupMetadataUnexpectedFailure() => 'backupMetadataUnexpected',
  };
}
