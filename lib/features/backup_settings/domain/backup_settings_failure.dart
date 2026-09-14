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

/// The twelve magic backup words cannot be derived on this device, because no
/// default seed is available to derive them from.
///
/// Kept apart from [BackupSettingsUnavailableFailure], which is about a server
/// this app could not reach: nothing is wrong here, the words simply live with
/// a wallet this phone does not hold.
final class BackupSettingsBackupWordsUnavailableFailure
    extends BackupSettingsFailure {
  const BackupSettingsBackupWordsUnavailableFailure();
}

/// What was typed is not a valid set of twelve backup words.
///
/// It carries nothing about the input: the words are the credential, so even a
/// word count or a misspelling must not reach a log or a message.
final class BackupSettingsInvalidBackupWordsFailure
    extends BackupSettingsFailure {
  const BackupSettingsInvalidBackupWordsFailure();
}

/// The text supplied is not a public account key this app can look up under.
final class BackupSettingsInvalidAccountKeyFailure
    extends BackupSettingsFailure {
  const BackupSettingsInvalidAccountKeyFailure();
}
