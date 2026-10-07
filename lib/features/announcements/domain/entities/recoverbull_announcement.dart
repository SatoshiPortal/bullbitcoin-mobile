import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

/// A typed RecoverBull page and all source alerts consolidated into it.
final class RecoverBullAnnouncement extends Announcement {
  final RecoverBullAttemptAlert primaryAlert;
  final List<RecoverBullAttemptAlert> sourceAlerts;

  RecoverBullAnnouncement({required this.primaryAlert, required sourceAlerts})
    : assert(sourceAlerts.isNotEmpty),
      sourceAlerts = List.unmodifiable(sourceAlerts),
      super(
        id: _idFor(primaryAlert.kind),
        priority: 0,
        tone: AnnouncementTone.error,
        action: const NavigateAction(),
        dismissPolicy: const PermanentDismiss(),
        stableKey: 'recoverbull:${primaryAlert.correlationId}',
      );
}

AnnouncementId _idFor(RecoverBullAttemptAlertKind kind) => switch (kind) {
  RecoverBullAttemptAlertKind.suspiciousActivity ||
  RecoverBullAttemptAlertKind.targetedLockout =>
    AnnouncementId.recoverBullTargetedActivity,
  RecoverBullAttemptAlertKind.servicePressure =>
    AnnouncementId.recoverBullServicePressure,
  RecoverBullAttemptAlertKind.identifierSaturation =>
    AnnouncementId.recoverBullServicePressure,
  RecoverBullAttemptAlertKind.unavailable =>
    AnnouncementId.recoverBullUnavailable,
};
