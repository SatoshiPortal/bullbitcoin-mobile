import 'package:drift/drift.dart';

/// Persisted record that the user has dismissed a home announcement.
///
/// One row per dismissed announcement, keyed by the announcement's stable
/// string id (the `AnnouncementId` enum name). A row's mere existence means
/// "dismissed"; [dismissedAt] lets a *periodic* announcement re-arm once
/// enough time has elapsed (snooze), while a *permanent* announcement simply
/// stays suppressed for as long as the row exists.
///
/// Announcements themselves are defined in code (compile-time), not stored —
/// only the per-user dismissal fact is persisted here.
@DataClassName('DismissedAnnouncementRow')
class DismissedAnnouncements extends Table {
  /// The `AnnouncementId` enum name (stable across releases).
  TextColumn get announcementId => text()();

  /// When the user dismissed it (UTC). Used to re-arm snooze-policy
  /// announcements; ignored for permanent-policy ones.
  DateTimeColumn get dismissedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {announcementId};
}
