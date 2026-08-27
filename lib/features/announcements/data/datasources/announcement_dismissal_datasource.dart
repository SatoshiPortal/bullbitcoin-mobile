import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/announcements/data/models/announcement_dismissal_model.dart';

/// Wraps the `dismissed_announcements` Drift table. Private to its repository;
/// speaks the wire/persistence shape (`AnnouncementDismissalModel`), never a
/// domain entity.
class AnnouncementDismissalDatasource {
  final SqliteDatabase _sqlite;

  AnnouncementDismissalDatasource({required this._sqlite});

  Future<List<AnnouncementDismissalModel>> fetchAll() async {
    final rows = await _sqlite.managers.dismissedAnnouncements.get();
    return rows
        .map(
          (r) => AnnouncementDismissalModel(
            announcementId: r.announcementId,
            dismissedAt: r.dismissedAt,
          ),
        )
        .toList();
  }

  /// Upserts the dismissal: inserts a new row or refreshes the timestamp of an
  /// existing one (keyed by [announcementId]).
  Future<void> upsert(String announcementId, DateTime dismissedAt) async {
    await _sqlite
        .into(_sqlite.dismissedAnnouncements)
        .insertOnConflictUpdate(
          DismissedAnnouncementsCompanion.insert(
            announcementId: announcementId,
            dismissedAt: dismissedAt,
          ),
        );
  }
}
