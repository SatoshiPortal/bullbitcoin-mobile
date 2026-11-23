import 'package:drift/drift.dart';

@DataClassName('DismissedAnnouncementRow')
class DismissedAnnouncements extends Table {
  TextColumn get announcementId => text()();

  DateTimeColumn get dismissedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {announcementId};
}
