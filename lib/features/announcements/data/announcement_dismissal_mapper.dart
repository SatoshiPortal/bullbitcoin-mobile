import 'package:bb_mobile/features/announcements/data/announcement_dismissal_model.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_dismissal.dart';

/// Translates the persisted dismissal model to the domain entity.
extension AnnouncementDismissalMapper on AnnouncementDismissalModel {
  /// Returns the domain entity, or `null` when the stored id is not a known
  /// [AnnouncementId] (e.g. a row written by a newer build, then downgraded) —
  /// callers skip unknown ids rather than crash.
  AnnouncementDismissal? toEntity() {
    final id = AnnouncementId.values
        .where((v) => v.name == announcementId)
        .firstOrNull;
    if (id == null) return null;
    return AnnouncementDismissal(id: id, dismissedAt: dismissedAt);
  }
}
