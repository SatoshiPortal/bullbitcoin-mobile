import 'package:announcements/generated/l10n/announcements_localizations.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:flutter/widgets.dart';

/// Localized user-facing content for each announcement. Kept in presentation so
/// the domain stays Flutter-free; the `sealed`-like exhaustive switch over the
/// closed [AnnouncementId] enum makes a missing string a compile-time warning
/// (unhandled enum value).
extension AnnouncementL10n on Announcement {
  String title(BuildContext context) => switch (id) {
    AnnouncementId.payjoinPrivacy => AnnouncementsLocalizations.of(
      context,
    ).announcementPayjoinTitle,
    AnnouncementId.appUpdateRequired => AnnouncementsLocalizations.of(
      context,
    ).announcementAppUpdateRequiredTitle,
  };

  String description(BuildContext context) => switch (id) {
    AnnouncementId.payjoinPrivacy => AnnouncementsLocalizations.of(
      context,
    ).announcementPayjoinDescription,
    AnnouncementId.appUpdateRequired => AnnouncementsLocalizations.of(
      context,
    ).announcementAppUpdateRequiredDescription,
  };
}
