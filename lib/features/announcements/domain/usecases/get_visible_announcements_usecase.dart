import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/announcements/domain/announcements_failure.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_catalog.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

/// Orchestrates which announcements are currently visible on the home carousel.
///
/// Thin orchestration only: it asks each catalog entry whether its trigger
/// fires for the current [AnnouncementSignals], drops anything the user has
/// dismissed (respecting the per-announcement dismiss policy), and returns
/// the survivors ordered by ascending priority. All decision *rules* live on
/// the entities / catalog; this use-case only wires signals to them. (The
class GetVisibleAnnouncementsUsecase {
  final AnnouncementDismissalRepository _dismissalRepository;
  final SwapFacade _swapFacade;

  GetVisibleAnnouncementsUsecase(this._dismissalRepository, this._swapFacade);

  Future<Result<List<Announcement>, AnnouncementsFailure>> execute() async {
    try {
      final dismissals = await _dismissalRepository.getDismissals();

      final signals = AnnouncementSignals(
        isAppUpdateRequired: _swapFacade.isAppUpdateRequired,
      );
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
