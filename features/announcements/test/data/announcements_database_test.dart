import 'package:announcements/src/data/announcements_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps the historical timestamp text and unknown announcement IDs',
    () async {
      final database = AnnouncementsDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const id = 'olderAppOnly';
      const timestamp = '2026-11-22 13:14:12.345678Z';

      await database.customStatement(
        'INSERT INTO dismissed_announcements VALUES (?, ?)',
        [id, timestamp],
      );

      final row = await database
          .select(database.dismissedAnnouncements)
          .getSingle();
      expect(row.announcementId, id);
      expect(row.dismissedAt, DateTime.parse(timestamp));
      final raw = await database
          .customSelect(
            'SELECT typeof(dismissed_at) AS storage, dismissed_at '
            'FROM dismissed_announcements',
          )
          .getSingle();
      expect(raw.read<String>('storage'), 'text');
      expect(raw.read<String>('dismissed_at'), timestamp);
    },
  );
}
