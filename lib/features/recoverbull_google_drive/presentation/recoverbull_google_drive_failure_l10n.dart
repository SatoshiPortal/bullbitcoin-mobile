import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/domain/recoverbull_google_drive_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [RecoverBullGoogleDriveFailure]. The
/// `sealed` switch makes a missing message a compile error. Never returns the
/// raw `logMessage`.
extension RecoverBullGoogleDriveFailureL10n on RecoverBullGoogleDriveFailure {
  String toTranslated(BuildContext context) => switch (this) {
    RecoverBullGoogleDriveUnexpectedFailure() =>
      context.loc.recoverbullGoogleDriveErrorFetchFailed,
  };
}
