import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v12.dart' as v12;
import 'generated/schema_v13.dart' as v13;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('v12 to v13: swaps refund columns, status backfill, frozen_utxos', () {
    test('completed swap with refund txid is backfilled to refunded', () async {
      final schema = await verifier.schemaAt(12);

      final oldDb = v12.DatabaseAtV12(schema.newConnection());
      await oldDb
          .into(oldDb.swaps)
          .insert(
            v12.SwapsCompanion.insert(
              id: 'refundedswap',
              type: 'liquidToLightning',
              direction: 'send',
              status: 'completed',
              isTestnet: 0,
              keyIndex: 0,
              creationTime: 1700000000000,
              sendWalletId: const Value('w1'),
              invoice: const Value('lnbc1'),
              paymentAddress: const Value('lq1'),
              paymentAmount: const Value(10000),
              sendTxid: const Value('lockup-tx'),
              refundTxid: const Value('refund-tx'),
            ),
          );
      await oldDb
          .into(oldDb.swaps)
          .insert(
            v12.SwapsCompanion.insert(
              id: 'normalswap12',
              type: 'liquidToLightning',
              direction: 'send',
              status: 'completed',
              isTestnet: 0,
              keyIndex: 1,
              creationTime: 1700000000000,
              sendWalletId: const Value('w1'),
              invoice: const Value('lnbc2'),
              paymentAddress: const Value('lq1'),
              paymentAmount: const Value(10000),
              sendTxid: const Value('lockup-tx-2'),
            ),
          );
      await oldDb.close();

      final db = SqliteDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 13);
      await db.close();

      final migratedDb = v13.DatabaseAtV13(schema.newConnection());
      final swaps = await migratedDb.select(migratedDb.swaps).get();

      final refunded = swaps.singleWhere((s) => s.id == 'refundedswap');
      expect(refunded.status, 'refunded');
      expect(refunded.refundFees, isNull);
      expect(refunded.wasDirectPayment, 0);

      final completed = swaps.singleWhere((s) => s.id == 'normalswap12');
      expect(completed.status, 'completed');

      // The collapsed step also creates the frozen_utxos table (issue #760,
      // formerly the separate v13→v14 hop). Confirm it exists and is writable.
      await migratedDb
          .into(migratedDb.frozenUtxos)
          .insert(
            v13.FrozenUtxosCompanion.insert(
              walletId: 'w1',
              txId: 'tx1',
              vout: 0,
            ),
          );
      final frozen = await migratedDb.select(migratedDb.frozenUtxos).get();
      expect(frozen, hasLength(1));
      expect(frozen.single.walletId, 'w1');

      await migratedDb.close();
    });
  });
}
