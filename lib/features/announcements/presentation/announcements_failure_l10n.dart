import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [AnnouncementsFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
extension AnnouncementsFailureL10n on AnnouncementsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AnnouncementStorageFailure() => context.loc.oopsSomethingWentWrong,
    AnnouncementUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
