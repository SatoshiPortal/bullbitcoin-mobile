import 'package:bb_mobile/core/failures/failure.dart';

sealed class BackupSettingsFailure extends Failure {
  const BackupSettingsFailure([super.logMessage]);
}

final class BackupSettingsUnexpectedFailure extends BackupSettingsFailure {
  const BackupSettingsUnexpectedFailure([super.logMessage]);
}

final class BackupSettingsUnavailableFailure extends BackupSettingsFailure {
  const BackupSettingsUnavailableFailure();
}

final class BackupSettingsDisabledFailure extends BackupSettingsFailure {
  const BackupSettingsDisabledFailure();
}

final class BackupSettingsUpdateRequiredFailure extends BackupSettingsFailure {
  const BackupSettingsUpdateRequiredFailure();
}

final class BackupSettingsInvalidServerFailure extends BackupSettingsFailure {
  const BackupSettingsInvalidServerFailure();
}

final class BackupSettingsFileReadFailure extends BackupSettingsFailure {
  const BackupSettingsFileReadFailure();
}

final class BackupSettingsFileSaveFailure extends BackupSettingsFailure {
  const BackupSettingsFileSaveFailure();
}

final class BackupSettingsFileTooLargeFailure extends BackupSettingsFailure {
  const BackupSettingsFileTooLargeFailure();
}

final class BackupSettingsInvalidFileFailure extends BackupSettingsFailure {
  const BackupSettingsInvalidFileFailure();
}

/// The backup decoded, but it was sealed to another recovery phrase.
///
/// Kept apart from [BackupSettingsInvalidFileFailure] because a readable backup
/// from the wrong seed is not a damaged one, and telling the user otherwise
/// sends them looking for a corrupt file (spec F17, 21.2).
final class BackupSettingsSeedMismatchFailure extends BackupSettingsFailure {
  const BackupSettingsSeedMismatchFailure();
}

/// The server refused the credentials, or answered with something this client
/// cannot authenticate.
final class BackupSettingsUnverifiedFailure extends BackupSettingsFailure {
  const BackupSettingsUnverifiedFailure();
}

/// Another installation moved the remote head.
final class BackupSettingsHeadConflictFailure extends BackupSettingsFailure {
  const BackupSettingsHeadConflictFailure();
}

/// Local storage refused a read or a write. Nothing about the backup is wrong.
final class BackupSettingsStorageFailure extends BackupSettingsFailure {
  const BackupSettingsStorageFailure();
}

/// A recovery stopped part way, so some restored data still needs the user.
final class BackupSettingsRecoveryNeedsAttentionFailure
    extends BackupSettingsFailure {
  const BackupSettingsRecoveryNeedsAttentionFailure();
}
