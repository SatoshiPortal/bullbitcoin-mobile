import 'package:announcements/generated/l10n/announcements_localizations.dart';
import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [AnnouncementsFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
extension AnnouncementsFailureL10n on AnnouncementsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AnnouncementStorageFailure() => AnnouncementsLocalizations.of(
      context,
    ).oopsSomethingWentWrong,
    AnnouncementUnexpectedFailure() => AnnouncementsLocalizations.of(
      context,
    ).oopsSomethingWentWrong,
  };
}
