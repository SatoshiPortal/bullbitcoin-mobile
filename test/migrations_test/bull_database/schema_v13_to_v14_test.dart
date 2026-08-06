import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v14.dart' as v14;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

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
              destination: 'invoice',
              fallback: 'fallback',
              createdAt: '2026-08-05T12:00:00.000Z',
              localStatus: 'creating',
            ),
          );

      final rows = await migratedDb.select(migratedDb.orderSwaps).get();
      expect(rows.single.localId, 'local-1');
      expect(rows.single.requestId, 'request-1');
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
