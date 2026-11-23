import 'package:primitives/primitives.dart';
import 'package:announcements/src/domain/announcements_failure.dart';
import 'package:announcements/src/domain/entities/announcement.dart';
import 'package:announcements/src/domain/entities/announcement_catalog.dart';
import 'package:meta/meta.dart';

import '../announcement_dismissals.dart';

/// Orchestrates which announcements are currently visible on the home carousel.
///
/// Thin orchestration only: it asks each catalog entry whether its trigger
/// fires for the current [AnnouncementSignals], drops anything the user has
/// dismissed (respecting the per-announcement dismiss policy), and returns
/// the survivors ordered by ascending priority. All decision *rules* live on
/// the entities / catalog; this use-case only wires signals to them.
class GetVisibleAnnouncementsUsecase {
  final AnnouncementDismissals _dismissals;
  final bool Function() _isAppUpdateRequired;

  GetVisibleAnnouncementsUsecase(this._dismissals, this._isAppUpdateRequired);

  @useResult
  Future<Result<List<Announcement>, AnnouncementsFailure>> execute() async {
    final result = await _dismissals.read();
    try {
      return result.map((dismissals) {
        final signals = AnnouncementSignals(
          isAppUpdateRequired: _isAppUpdateRequired(),
        );
        final dismissedAtById = {
          for (final d in dismissals) d.id: d.dismissedAt,
        };
        final now = DateTime.now().toUtc();

        final visible = <Announcement>[];
        for (final entry in announcementCatalog) {
          if (!entry.triggersFor(signals)) continue;

          final dismissedAt = dismissedAtById[entry.announcement.id.name];
          final suppressed =
              dismissedAt != null &&
              entry.announcement.isSuppressedBy(dismissedAt, now: now);
          if (suppressed) continue;

          visible.add(entry.announcement);
        }

        visible.sort((a, b) => a.priority.compareTo(b.priority));
        return visible;
      });
    } on Exception catch (error) {
      return Err(AnnouncementUnexpectedFailure(error.runtimeType.toString()));
    }
  }
}
