import 'package:bull_recoverbull/src/domain/recoverbull_google_drive_failure.dart';
import 'package:flutter/widgets.dart';
import 'package:bull_recoverbull/src/l10n/context_localizations.dart';

/// User-facing, localized message for each [RecoverBullGoogleDriveFailure]. The
/// `sealed` switch makes a missing message a compile error. Never returns the
/// raw `logMessage`.
extension RecoverBullGoogleDriveFailureL10n on RecoverBullGoogleDriveFailure {
  String toTranslated(BuildContext context) => switch (this) {
    RecoverBullGoogleDriveFetchFailure() =>
      context.loc.recoverbullGoogleDriveErrorFetchFailed,
    RecoverBullGoogleDriveDeleteFailure() =>
      context.loc.recoverbullGoogleDriveErrorDeleteFailed,
    RecoverBullGoogleDriveExportFailure() =>
      context.loc.recoverbullGoogleDriveErrorExportFailed,
  };
}
