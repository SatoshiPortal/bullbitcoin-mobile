import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_recoverbull_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';

/// Records that the user dismissed an announcement, so it stops showing
/// (permanently or until its snooze interval elapses, per its dismiss policy).
class DismissAnnouncementUsecase {
  final AnnouncementDismissalRepository _dismissalRepository;
  final DismissRecoverBullAnnouncementUsecase? dismissRecoverBull;

  DismissAnnouncementUsecase({
    required this._dismissalRepository,
    this.dismissRecoverBull,
  });

  Future<Result<void, AnnouncementsFailure>> execute(
    Announcement announcement,
  ) async {
    try {
      if (announcement case final RecoverBullAnnouncement recoverBull) {
        await dismissRecoverBull!.execute(recoverBull);
      } else {
        await _dismissalRepository.dismiss(announcement.id);
      }
      return const Ok(null);
    } catch (e) {
      return Err(AnnouncementStorageFailure(e.toString()));
    }
  }
}
