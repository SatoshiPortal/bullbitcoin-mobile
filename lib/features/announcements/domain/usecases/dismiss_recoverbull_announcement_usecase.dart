import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

final class DismissRecoverBullAnnouncementUsecase {
  final RecoverBullAttemptMonitoringController _monitoring;

  const DismissRecoverBullAnnouncementUsecase(this._monitoring);

  Future<void> execute(RecoverBullAnnouncement announcement) async {
    for (final alert in announcement.sourceAlerts) {
      await _monitoring.acknowledge(alert);
    }
  }
}
