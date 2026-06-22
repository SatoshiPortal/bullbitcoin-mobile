import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the RecoverBull Google Drive flow surfaces to
/// the user. Foreign errors (Drive API, auth) are caught at the feature
/// boundary — the bloc — and mapped into one of these variants; the raw reason
/// stays in the logs. `sealed` keeps it closed. Pure Dart — the user-facing
/// message lives in `recoverbull_google_drive_failure_l10n.dart`.
sealed class RecoverBullGoogleDriveFailure extends Failure {
  const RecoverBullGoogleDriveFailure([super.logMessage]);
}

/// Catch-all for Drive read/write/delete/export failures. [logMessage] is for
/// logs ONLY and MUST never reach the UI — the presentation extension returns a
/// fixed user-facing string.
final class RecoverBullGoogleDriveUnexpectedFailure
    extends RecoverBullGoogleDriveFailure {
  const RecoverBullGoogleDriveUnexpectedFailure([super.logMessage]);
}
