import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.drift.dart';
import 'package:bb_mobile/core/storage/tables/swaps_table.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/migration.dart';
import 'package:swaps/swaps.dart' hide SwapDirection;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase appDb;
  late BoltzSwapsDatabase swapsDb;
  late DriftSwapRowStore rows;
  late Directory directory;
  late File root;
  late BoltzCutover migration;
  late NativeFileGate gate;

  Future<void> run() async {
    final admission = await gate.acquire(
      exclusive: true,
      timeout: const Duration(seconds: 2),
    ) as ExclusiveAdmission;
    try {
      final owner = await migration.participant.prepare(
        admission,
        OwnerOrigin.legacy,
      );
      expect(owner, isA<Ok>());
      final prepared = (owner as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(
        await prepared.importLegacy(
          LegacySource(root, SqliteDatabase.currentSchemaVersion),
        ),
        isA<Ok>(),
      );
      expect(await prepared.close(), isA<Ok>());
    } finally {
      await admission.close();
    }
  }

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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('boltz-owner-');
    root = File('${directory.path}/root.sqlite');
    final file = File('${directory.path}/swaps.sqlite');
    appDb = SqliteDatabase(NativeDatabase(root));
    swapsDb = BoltzSwapsDatabase(NativeDatabase(file));
    rows = DriftSwapRowStore(swapsDb);
    gate = NativeFileGate(File('${directory.path}/lifecycle.lock'));
    migration = BoltzCutover(
      file: file,
      standalone: File('${directory.path}/boltz_swaps.sqlite'),
      regtest: false,
      executor: (_) => _executor(file.path),
    );
  });

  tearDown(() async {
    await appDb.close();
    await swapsDb.close();
    await directory.delete(recursive: true);
  });

  test('preserves incomplete rows without claiming they are usable', () async {
    await insertRow('chainSwap001', direction: SwapDirection.onchain);
    await insertRow(
      'brokenSend01',
      direction: SwapDirection.send,
      paymentAddress: null,
    );

    await run();

    expect(await rows.fetch('chainSwap001'), isNotNull);
    final incomplete = await (swapsDb.select(
      swapsDb.swaps,
    )..where((table) => table.id.equals('brokenSend01'))).getSingle();
    expect(incomplete.paymentAddress, isNull);
    expect(
      await hasLegacyImportReceipt(swapsDb, 'split-v1/swaps'),
      isA<Ok<bool, LegacyImportFailure>>().having(
        (r) => r.value,
        'receipt',
        true,
      ),
    );
  });

  test('carries the refunded backfill across', () async {
    await insertRow(
      'refunded0001',
      direction: SwapDirection.onchain,
      status: 'completed',
      refundTxid: 'refund-txid',
    );

    await run();

    expect((await rows.fetch('refunded0001'))?.status, 'refunded');
  });

  test('runs once and never overwrites what the engine wrote', () async {
    await insertRow('chainSwap001', direction: SwapDirection.onchain);
    await run();
    final imported = await rows.fetch('chainSwap001');
    if (imported == null) fail('chain swap was not imported');
    await rows.store(imported.copyWith(status: 'paid'));
    await insertRow('lateRow00001', direction: SwapDirection.onchain);

    await run();

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

    await run();

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

Future<Result<QueryExecutor, LegacyImportFailure>> Function() _executor(
  String path,
) =>
    () async => Ok(NativeDatabase(File(path)));
