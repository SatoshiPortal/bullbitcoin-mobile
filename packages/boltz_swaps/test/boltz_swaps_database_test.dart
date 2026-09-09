import 'package:boltz_swaps/src/data/db/boltz_swaps_database.dart';
import 'package:boltz_swaps/src/data/db/drift_swap_row_store.dart';
import 'package:boltz_swaps/src/data/models/swap_model.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late BoltzSwapsDatabase db;
  late DriftSwapRowStore rows;

  SwapModel chain(String id, {String? refundTxid}) => SwapModel.chain(
    id: id,
    type: 'liquidToBitcoin',
    status: refundTxid != null ? 'refunded' : 'refundable',
    keyIndex: 0,
    creationTime: DateTime(2026, 7).millisecondsSinceEpoch,
    sendWalletId: 'w-liquid',
    paymentAddress: 'lq1lockup',
    paymentAmount: 100000,
    sendTxid: 'lockup-$id',
    refundTxid: refundTxid,
  );

  setUp(() {
    db = BoltzSwapsDatabase(NativeDatabase.memory());
    rows = DriftSwapRowStore(db);
  });

  tearDown(() => db.close());

  test('import commits rows and marker atomically and only once', () async {
    await db.runDataMigration('test-import', () async {
      await rows.insertIfAbsent(chain('AAAAAAAAAAAA'));
    });

    expect(await db.dataMigrationDone('test-import'), isTrue);
    expect(await rows.fetch('AAAAAAAAAAAA'), isNotNull);

    var reran = false;
    await db.runDataMigration('test-import', () async {
      reran = true;
    });
    expect(reran, isFalse);
  });

  test(
    'a retried import never clobbers a row the engine already wrote',
    () async {
      // Engine recorded a refund between two import attempts.
      await rows.store(chain('BBBBBBBBBBBB', refundTxid: 'refund-done'));

      await db.runDataMigration('retry-import', () async {
        // Legacy source still holds the stale pre-refund row.
        await rows.insertIfAbsent(chain('BBBBBBBBBBBB'));
      });

      final kept = await rows.fetch('BBBBBBBBBBBB');
      expect((kept! as ChainSwapModel).refundTxid, 'refund-done');
      expect(kept.status, 'refunded');
    },
  );

  test('a failing import rolls back completely — no rows, no marker', () async {
    await expectLater(
      db.runDataMigration('broken-import', () async {
        await rows.insertIfAbsent(chain('CCCCCCCCCCCC'));
        throw StateError('row 2 was malformed');
      }),
      throwsStateError,
    );

    expect(await db.dataMigrationDone('broken-import'), isFalse);
    expect(await rows.fetch('CCCCCCCCCCCC'), isNull);
  });
}
