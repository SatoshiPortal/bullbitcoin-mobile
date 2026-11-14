import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:bb_mobile/core/swaps/boltz_swaps_db_migration.dart';
import 'package:swaps/swaps.dart' hide SwapDirection;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase appDb;
  late BoltzSwapsDatabase swapsDb;
  late DriftSwapRowStore rows;
  late BoltzSwapsDbMigration migration;

  Future<void> insertRow(
    String id, {
    required SwapDirection direction,
    String status = 'pending',
    String? paymentAddress = 'lockup-address',
    String? refundTxid,
  }) => appDb
      .into(appDb.swaps)
      .insert(
        SwapsCompanion.insert(
          id: id,
          type: direction == SwapDirection.onchain
              ? 'bitcoinToLiquid'
              : 'bitcoinToLightning',
          direction: direction,
          status: status,
          isTestnet: false,
          keyIndex: 0,
          creationTime: 1,
          sendWalletId: const Value('wallet-1'),
          paymentAddress: Value(paymentAddress),
          paymentAmount: const Value(1000),
          invoice: const Value('lnbc1'),
          refundTxid: Value(refundTxid),
        ),
      );

  setUp(() {
    appDb = SqliteDatabase(NativeDatabase.memory());
    swapsDb = BoltzSwapsDatabase(NativeDatabase.memory());
    rows = DriftSwapRowStore(swapsDb);
    migration = BoltzSwapsDbMigration(
      appDb: appDb,
      swapsDb: swapsDb,
      rows: rows,
    );
  });

  tearDown(() async {
    await appDb.close();
    await swapsDb.close();
  });

  test('an incomplete legacy row is skipped, the rest import', () async {
    await insertRow('chainSwap001', direction: SwapDirection.onchain);
    await insertRow(
      'brokenSend01',
      direction: SwapDirection.send,
      paymentAddress: null,
    );

    await migration.run();

    expect(await rows.fetch('chainSwap001'), isNotNull);
    expect(await rows.fetch('brokenSend01'), isNull);
    expect(await swapsDb.dataMigrationDone('app-db-swaps-v1'), isTrue);
  });

  test('carries the refunded backfill across', () async {
    await insertRow(
      'refunded0001',
      direction: SwapDirection.onchain,
      status: 'completed',
      refundTxid: 'refund-txid',
    );

    await migration.run();

    expect((await rows.fetch('refunded0001'))?.status, 'refunded');
  });

  test('runs once and never overwrites what the engine wrote', () async {
    await insertRow('chainSwap001', direction: SwapDirection.onchain);
    await migration.run();
    final imported = await rows.fetch('chainSwap001');
    if (imported == null) fail('chain swap was not imported');
    await rows.store(imported.copyWith(status: 'paid'));
    await insertRow('lateRow00001', direction: SwapDirection.onchain);

    await migration.run();

    expect((await rows.fetch('chainSwap001'))?.status, 'paid');
    expect(await rows.fetch('lateRow00001'), isNull);
  });
}
