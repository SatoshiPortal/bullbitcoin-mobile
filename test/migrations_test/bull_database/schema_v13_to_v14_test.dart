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

  test(
    'v13 to v14 creates writable order swap storage and its indexes',
    () async {
      final schema = await verifier.schemaAt(13);
      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 14);
      await db.close();

      final migratedDb = v14.DatabaseAtV14(schema.newConnection());
      await migratedDb
          .into(migratedDb.orderSwaps)
          .insert(
            v14.OrderSwapsCompanion.insert(
              localId: 'local-1',
              requestId: const Value('request-1'),
              purpose: 'sendLightning',
              environment: 'testnet',
              inNetwork: 'liquid',
              outNetwork: 'lightning',
              isInAmountFixed: 0,
              requestedAmountSat: 1000,
              quotedAmountSat: const Value(100000),
              destination: 'invoice',
              fallback: 'fallback',
              createdAt: '2026-08-05T12:00:00.000Z',
              localStatus: 'creating',
            ),
          );

      final rows = await migratedDb.select(migratedDb.orderSwaps).get();
      expect(rows.single.localId, 'local-1');
      expect(rows.single.requestId, 'request-1');
      expect(rows.single.quotedAmountSat, 100000);
      final indexes = await migratedDb
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'order_swaps_%'",
          )
          .map((row) => row.read<String>('name'))
          .get();
      expect(indexes, contains('order_swaps_local_status'));
      expect(indexes, contains('order_swaps_request_id'));
      expect(indexes, contains('order_swaps_source_wallet'));
      expect(indexes, contains('order_swaps_destination_wallet'));
      expect(indexes, contains('order_swaps_bitcoin_txid'));
      expect(indexes, contains('order_swaps_liquid_txid'));
      expect(indexes, contains('order_swaps_local_payin_txid'));

      await migratedDb.close();
    },
  );
}
