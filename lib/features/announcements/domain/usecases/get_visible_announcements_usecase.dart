import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_catalog.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';

/// Orchestrates which announcements are currently visible on the home carousel.
///
/// Thin orchestration only: it asks each catalog entry whether its trigger
/// fires for the current [AnnouncementSignals], drops anything the user has
/// dismissed (respecting the per-announcement dismiss policy), and returns
/// the survivors ordered by ascending priority. All decision *rules* live on
/// the entities / catalog; this use-case only wires signals to them. (The
/// catalog is currently empty — see its doc comment — so this returns an
/// empty list until a future announcement is added.)
class GetVisibleAnnouncementsUsecase {
  final AnnouncementDismissalRepository _dismissalRepository;

  GetVisibleAnnouncementsUsecase({required this._dismissalRepository});

  Future<Result<List<Announcement>, AnnouncementsFailure>> execute() async {
    try {
      final dismissals = await _dismissalRepository.getDismissals();

      const signals = AnnouncementSignals();
      final dismissedAtById = {for (final d in dismissals) d.id: d.dismissedAt};
      final now = DateTime.now().toUtc();

      final visible = <Announcement>[];
      for (final entry in announcementCatalog) {
        if (!entry.triggersFor(signals)) continue;

        final dismissedAt = dismissedAtById[entry.announcement.id];
        final suppressed =
            dismissedAt != null &&
            entry.announcement.isSuppressedBy(dismissedAt, now: now);
        if (suppressed) continue;

        visible.add(entry.announcement);
      }

      visible.sort((a, b) => a.priority.compareTo(b.priority));
      return Ok(visible);
    } catch (e) {
      return Err(AnnouncementUnexpectedFailure(e.toString()));
    }
  }
}
