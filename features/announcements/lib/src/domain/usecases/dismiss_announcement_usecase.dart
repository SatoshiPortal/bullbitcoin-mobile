import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../announcement_dismissals.dart';

/// Records the dismissal under the existing persisted announcement ID.
class DismissAnnouncementUsecase {
  final AnnouncementDismissals _dismissals;

  DismissAnnouncementUsecase({required this._dismissals});

  @useResult
  Future<Result<void, AnnouncementsFailure>> execute(AnnouncementId id) =>
      _dismissals.dismiss(id.name, DateTime.now().toUtc());
}
