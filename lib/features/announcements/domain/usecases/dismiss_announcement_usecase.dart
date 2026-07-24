import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';

/// Records that the user dismissed an announcement, so it stops showing
/// (permanently or until its snooze interval elapses, per its dismiss policy).
class DismissAnnouncementUsecase {
  final AnnouncementDismissalRepository _dismissalRepository;

  DismissAnnouncementUsecase({required this._dismissalRepository});

  Future<Result<void, AnnouncementsFailure>> execute(AnnouncementId id) async {
    try {
      await _dismissalRepository.dismiss(id);
      return const Ok(null);
    } catch (e) {
      return Err(AnnouncementStorageFailure(e.toString()));
    }
  }
}
