import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v14.dart' as v14;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v13 to v14: dismissed_announcements table', () {
    test('creates the dismissed_announcements table (empty by default) and it '
        'accepts a row', () async {
      final schema = await verifier.schemaAt(13);

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 14);
      await db.close();

      final migratedDb = v14.DatabaseAtV14(schema.newConnection());

      // Newly created table starts empty.
      final before = await migratedDb
          .select(migratedDb.dismissedAnnouncements)
          .get();
      expect(before, isEmpty);

      // And it is writable/readable. The DB stores DateTime as ISO-8601 text
      // (storeDateTimeAsText: true), so the generated v14 companion takes a
      // String for this column.
      const dismissedAt = '2026-07-20T00:00:00.000Z';
      await migratedDb
          .into(migratedDb.dismissedAnnouncements)
          .insert(
            v14.DismissedAnnouncementsCompanion.insert(
              announcementId: 'payjoinPrivacy',
              dismissedAt: dismissedAt,
            ),
          );

      final after = await migratedDb
          .select(migratedDb.dismissedAnnouncements)
          .get();
      expect(after, hasLength(1));
      expect(after.single.announcementId, 'payjoinPrivacy');
      expect(after.single.dismissedAt, dismissedAt);

      await migratedDb.close();
    });
  });
}
