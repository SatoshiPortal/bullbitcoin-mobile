import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:flutter/widgets.dart';

/// Localized user-facing content for each announcement. Kept in presentation so
/// the domain stays Flutter-free; the `sealed`-like exhaustive switch over the
/// closed [AnnouncementId] enum makes a missing string a compile-time warning
/// (unhandled enum value).
extension AnnouncementL10n on Announcement {
  String title(BuildContext context) => switch (id) {
    AnnouncementId.payjoinPrivacy => context.loc.announcementPayjoinTitle,
    AnnouncementId.autoswapActive => context.loc.announcementAutoswapTitle,
  };

  String description(BuildContext context) => switch (id) {
    AnnouncementId.payjoinPrivacy => context.loc.announcementPayjoinDescription,
    AnnouncementId.autoswapActive =>
      context.loc.announcementAutoswapDescription,
  };
}
