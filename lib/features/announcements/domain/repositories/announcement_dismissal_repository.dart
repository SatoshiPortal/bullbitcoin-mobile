import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_dismissal.dart';

/// The single source of truth for which announcements the user has dismissed.
///
/// Returns and accepts only domain types (never a Drift row / model). The
/// implementation lives in `data/` and wraps the `dismissed_announcements`
/// table.
abstract interface class AnnouncementDismissalRepository {
  /// All recorded dismissals, keyed by announcement id.
  Future<List<AnnouncementDismissal>> getDismissals();

  /// Records (or refreshes) a dismissal for [id] at the current time.
  Future<void> dismiss(AnnouncementId id);
}
