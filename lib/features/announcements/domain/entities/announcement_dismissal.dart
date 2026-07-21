import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';

/// A record that the user dismissed a given announcement at a given time.
///
/// Domain entity handed out by `AnnouncementDismissalRepository`; the wire/DB
/// shape lives in `data/models/` and never crosses the repository boundary.
class AnnouncementDismissal {
  final AnnouncementId id;
  final DateTime dismissedAt;

  AnnouncementDismissal({required this.id, required this.dismissedAt});
}
