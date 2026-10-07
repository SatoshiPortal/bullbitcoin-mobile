import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

class WatchRecoverBullAnnouncementsUsecase {
  final RecoverBullAttemptMonitoringController _monitoring;

  const WatchRecoverBullAnnouncementsUsecase(this._monitoring);

  Stream<List<RecoverBullAnnouncement>> execute() =>
      _monitoring.alerts.map(_map);

  List<RecoverBullAnnouncement> _map(List<RecoverBullAttemptAlert> alerts) {
    final grouped = <String, List<RecoverBullAttemptAlert>>{};
    for (final alert in alerts) {
      final key = alert.correlationId;
      grouped.putIfAbsent(key, () => []).add(alert);
    }
    return [
      for (final source in grouped.values)
        RecoverBullAnnouncement(
          primaryAlert:
              source.any(
                (alert) =>
                    alert.kind == RecoverBullAttemptAlertKind.targetedLockout,
              )
              ? source.firstWhere(
                  (alert) =>
                      alert.kind == RecoverBullAttemptAlertKind.targetedLockout,
                )
              : source.first,
          sourceAlerts: List.unmodifiable(source),
        ),
    ];
  }
}
