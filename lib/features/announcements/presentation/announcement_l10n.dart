import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';
import 'package:flutter/widgets.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

/// Localized user-facing content for each announcement. Kept in presentation so
/// the domain stays Flutter-free; the `sealed`-like exhaustive switch over the
/// closed [AnnouncementId] enum makes a missing string a compile-time warning
/// (unhandled enum value).
extension AnnouncementL10n on Announcement {
  String title(BuildContext context) => switch (id) {
    AnnouncementId.payjoinPrivacy => context.loc.announcementPayjoinTitle,
    AnnouncementId.appUpdateRequired =>
      context.loc.announcementAppUpdateRequiredTitle,
    AnnouncementId.recoverBullTargetedActivity => _targetedActivityTitle(
      context,
      this,
    ),
    AnnouncementId.recoverBullServicePressure => _servicePressureText(context),
    AnnouncementId.recoverBullUnavailable => RecoverBullLocalizations.of(
      context,
    ).recoverbullAttemptMonitoringUnavailableUnknownDuration,
  };

  String description(BuildContext context) => switch (id) {
    AnnouncementId.payjoinPrivacy => context.loc.announcementPayjoinDescription,
    AnnouncementId.appUpdateRequired =>
      context.loc.announcementAppUpdateRequiredDescription,
    AnnouncementId.recoverBullTargetedActivity => _targetedActivityDescription(
      context,
      this,
    ),
    AnnouncementId.recoverBullServicePressure => _servicePressureText(context),
    AnnouncementId.recoverBullUnavailable => RecoverBullLocalizations.of(
      context,
    ).recoverbullAttemptMonitoringUnavailableUnknownDuration,
  };

  String _targetedActivityTitle(BuildContext context, Announcement value) {
    final announcement = value as RecoverBullAnnouncement;
    final l10n = RecoverBullLocalizations.of(context);
    return announcement.sourceAlerts.any(
          (alert) => alert.kind == RecoverBullAttemptAlertKind.targetedLockout,
        )
        ? l10n.recoverbullAttemptMonitoringLockoutTitle
        : l10n.recoverbullAttemptMonitoringSuspiciousActivityTitle;
  }

  String _servicePressureText(BuildContext context) {
    final announcement = this as RecoverBullAnnouncement;
    final l10n = RecoverBullLocalizations.of(context);
    return announcement.sourceAlerts.any(
          (alert) =>
              alert.kind == RecoverBullAttemptAlertKind.identifierSaturation,
        )
        ? l10n.recoverbullAttemptMonitoringIdentifierSaturation
        : l10n.recoverbullAttemptMonitoringServicePressure;
  }

  String _targetedActivityDescription(
    BuildContext context,
    Announcement value,
  ) {
    final announcement = value as RecoverBullAnnouncement;
    final l10n = RecoverBullLocalizations.of(context);
    final hasLockout = announcement.sourceAlerts.any(
      (alert) => alert.kind == RecoverBullAttemptAlertKind.targetedLockout,
    );
    final hasCounter = announcement.sourceAlerts.any(
      (alert) => alert.kind == RecoverBullAttemptAlertKind.suspiciousActivity,
    );
    if (hasLockout && hasCounter) {
      return l10n.recoverbullAttemptMonitoringLockoutAnnouncement;
    }
    return hasLockout
        ? l10n.recoverbullAttemptMonitoringLockoutAnnouncement
        : l10n.recoverbullAttemptMonitoringSuspiciousActivityAnnouncement;
  }
}
