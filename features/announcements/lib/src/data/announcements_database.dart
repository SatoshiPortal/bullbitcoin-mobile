import 'package:drift/drift.dart';

part 'announcements_database.g.dart';

@DataClassName('DismissedAnnouncementRow')
class DismissedAnnouncements extends Table {
  TextColumn get announcementId => text()();
  DateTimeColumn get dismissedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {announcementId};
}

class LegacyImportReceipts extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DismissedAnnouncements, LegacyImportReceipts])
final class AnnouncementsDatabase extends _$AnnouncementsDatabase {
  static const schema = 1;

  AnnouncementsDatabase(super.executor);

  @override
  int get schemaVersion => schema;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => transaction(() async {
      for (final table in allTables) {
        final exists = await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable(table.actualTableName)],
        ).getSingleOrNull();
        if (exists == null) await m.createTable(table);
      }
    }),
  );
}
