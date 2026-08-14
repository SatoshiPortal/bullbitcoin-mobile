import 'package:bb_mobile/core/failures/failure.dart';

/// The announcements feature's sealed failure family (Flutter-free).
///
/// Its `toTranslated(BuildContext)` lives in the presentation layer
/// (`presentation/announcements_failure_l10n.dart`), never here.
sealed class AnnouncementsFailure extends Failure {
  const AnnouncementsFailure([super.logMessage]);
}

/// A dismissal could not be read from or written to persistent storage.
final class AnnouncementStorageFailure extends AnnouncementsFailure {
  const AnnouncementStorageFailure([super.logMessage]);
}

/// Catch-all for anything not modeled above. The UI renders a generic
/// localized message for this — never the raw [logMessage].
final class AnnouncementUnexpectedFailure extends AnnouncementsFailure {
  const AnnouncementUnexpectedFailure([super.logMessage]);
}
