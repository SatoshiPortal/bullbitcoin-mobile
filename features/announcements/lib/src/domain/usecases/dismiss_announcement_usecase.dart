import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' show AnnouncementDismissals;
import 'package:primitives/primitives.dart';

/// Records the dismissal under the existing persisted announcement ID.
class DismissAnnouncementUsecase {
  final AnnouncementDismissals _dismissals;

  DismissAnnouncementUsecase({required this._dismissals});

  @useResult
  Future<Result<void, AnnouncementsFailure>> execute(AnnouncementId id) async {
    final result = await _dismissals.dismiss(id.name, DateTime.now().toUtc());
    return result.mapErr(
      (failure) => AnnouncementStorageFailure(failure.logMessage),
    );
  }
}
