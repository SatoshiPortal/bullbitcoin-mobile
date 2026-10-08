import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Resolves each announcement to the route its [NavigateAction] opens.
///
/// Lives in the ui layer so `domain/` never imports another feature's router
/// (AGENTS.md rule #1 + Flutter-free domain). The exhaustive `switch` over the
/// closed [AnnouncementId] enum makes a missing mapping a compile-time warning.
extension AnnouncementNavigation on Announcement {
  SettingsRoute get route => switch (id) {
    AnnouncementId.payjoinPrivacy => SettingsRoute.payjoinSettings,
    AnnouncementId.appUpdateRequired => throw UnsupportedError(
      'The app update announcement does not navigate',
    ),
    AnnouncementId.recoverBullTargetedActivity ||
    AnnouncementId.recoverBullServicePressure ||
    AnnouncementId.recoverBullUnavailable => throw UnsupportedError(
      'RecoverBull navigation is resolved by the carousel',
    ),
  };

  void open(BuildContext context) {
    if (this case final RecoverBullAnnouncement announcement) {
      openRecoverBullAttemptAlertDetails(context, announcement.sourceAlerts);
      return;
    }
    context.pushNamed(route.name);
  }
}
