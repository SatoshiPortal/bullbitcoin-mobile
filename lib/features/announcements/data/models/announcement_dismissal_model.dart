/// Wire/persistence shape of a dismissal record. Pure data — mirrors the
/// `dismissed_announcements` Drift row. Never crosses the repository boundary
/// (the repo maps it to `AnnouncementDismissal`).
class AnnouncementDismissalModel {
  /// The `AnnouncementId` enum name as stored.
  final String announcementId;
  final DateTime dismissedAt;

  const AnnouncementDismissalModel({
    required this.announcementId,
    required this.dismissedAt,
  });
}
