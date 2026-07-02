import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the RecoverBull Google Drive flow surfaces to
/// the user. Foreign errors (Drive API, auth) are caught at the feature
/// boundary — the bloc — and mapped into one of these variants; the raw reason
/// stays in the logs. `sealed` keeps it closed. Pure Dart — the user-facing
/// message lives in `recoverbull_google_drive_failure_l10n.dart`.
sealed class RecoverBullGoogleDriveFailure extends Failure {
  const RecoverBullGoogleDriveFailure([super.logMessage]);
}

/// Fetching the vault list, or a vault's contents, from Drive failed.
final class RecoverBullGoogleDriveFetchFailure
    extends RecoverBullGoogleDriveFailure {
  const RecoverBullGoogleDriveFetchFailure([super.logMessage]);
}

/// Deleting a vault from Drive failed.
final class RecoverBullGoogleDriveDeleteFailure
    extends RecoverBullGoogleDriveFailure {
  const RecoverBullGoogleDriveDeleteFailure([super.logMessage]);
}

/// Exporting a vault out of Drive failed.
final class RecoverBullGoogleDriveExportFailure
    extends RecoverBullGoogleDriveFailure {
  const RecoverBullGoogleDriveExportFailure([super.logMessage]);
}
