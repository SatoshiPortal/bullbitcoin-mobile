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

  test('finished swaps of every kind keep their history', () async {
    await appDb.batch((batch) {
      batch.insertAll(appDb.swaps, [
        SwapsCompanion.insert(
          id: 'receiveDone1',
          type: 'lightningToBitcoin',
          direction: SwapDirection.receive,
          status: 'completed',
          isTestnet: false,
          keyIndex: 3,
          creationTime: 100,
          completionTime: const Value(200),
          receiveWalletId: const Value('wallet-btc'),
          receiveAddress: const Value('bc1-receive'),
          receiveTxid: const Value('receive-txid'),
          invoice: const Value('lnbc-receive'),
          boltzFees: const Value(25),
          lockupFees: const Value(150),
          claimFees: const Value(140),
        ),
        SwapsCompanion.insert(
          id: 'sendDone0001',
          type: 'liquidToLightning',
          direction: SwapDirection.send,
          status: 'completed',
          isTestnet: false,
          keyIndex: 4,
          creationTime: 300,
          completionTime: const Value(400),
          sendWalletId: const Value('wallet-lbtc'),
          paymentAddress: const Value('lq-lockup'),
          paymentAmount: const Value(5000),
          invoice: const Value('lnbc-send'),
          sendTxid: const Value('send-txid'),
          preimage: const Value('send-preimage'),
          boltzFees: const Value(5),
          lockupFees: const Value(30),
        ),
        SwapsCompanion.insert(
          id: 'chainDone001',
          type: 'liquidToBitcoin',
          direction: SwapDirection.onchain,
          status: 'completed',
          isTestnet: false,
          keyIndex: 5,
          creationTime: 500,
          completionTime: const Value(600),
          sendWalletId: const Value('wallet-lbtc'),
          receiveWalletId: const Value('wallet-btc'),
          paymentAddress: const Value('lq-chain-lockup'),
          paymentAmount: const Value(60000),
          receiveAddress: const Value('bc1-chain-receive'),
          sendTxid: const Value('chain-send-txid'),
          receiveTxid: const Value('chain-receive-txid'),
          boltzFees: const Value(60),
          lockupFees: const Value(40),
          claimFees: const Value(200),
          serverNetworkFees: const Value(300),
        ),
      ]);
    });

    await migration.run();

    final receive = (await rows.fetch('receiveDone1'))?.toJson();
    expect(receive, containsPair('status', 'completed'));
    expect(receive, containsPair('keyIndex', 3));
    expect(receive, containsPair('completionTime', 200));
    expect(receive, containsPair('receiveTxid', 'receive-txid'));
    expect(receive, containsPair('invoice', 'lnbc-receive'));
    expect(receive, containsPair('claimFees', 140));

    final send = (await rows.fetch('sendDone0001'))?.toJson();
    expect(send, containsPair('status', 'completed'));
    expect(send, containsPair('paymentAmount', 5000));
    expect(send, containsPair('sendTxid', 'send-txid'));
    expect(send, containsPair('preimage', 'send-preimage'));
    expect(send, containsPair('completionTime', 400));

    final chain = (await rows.fetch('chainDone001'))?.toJson();
    expect(chain, containsPair('status', 'completed'));
    expect(chain, containsPair('receiveWalletId', 'wallet-btc'));
    expect(chain, containsPair('sendTxid', 'chain-send-txid'));
    expect(chain, containsPair('receiveTxid', 'chain-receive-txid'));
    expect(chain, containsPair('serverNetworkFees', 300));
    expect(chain, containsPair('completionTime', 600));
  });
}
