import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/migration.dart';
import 'package:swaps/src/data/db/boltz_swaps_database.dart';
import 'package:swaps/src/data/db/drift_swap_row_store.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _LegacyRoot appDb;
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
        await prepared.importLegacy(LegacySource(root, _LegacyRoot.version)),
        isA<Ok>(),
      );
      expect(await prepared.close(), isA<Ok>());
    } finally {
      await admission.close();
    }
  }

  Future<void> insertRow(
    String id, {
    required SwapRowDirection direction,
    String status = 'pending',
    String? paymentAddress = 'lockup-address',
    String? refundTxid,
  }) => appDb
      .into(appDb.swaps)
      .insert(
        SwapsCompanion.insert(
          id: id,
          type: direction == SwapRowDirection.onchain
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
    appDb = _LegacyRoot(NativeDatabase(root));
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
    await insertRow('chainSwap001', direction: SwapRowDirection.onchain);
    await insertRow(
      'brokenSend01',
      direction: SwapRowDirection.send,
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
      direction: SwapRowDirection.onchain,
      status: 'completed',
      refundTxid: 'refund-txid',
    );

    await run();

    expect((await rows.fetch('refunded0001'))?.status, 'refunded');
  });

  test('reopens a raw refundable swap skipped by the old import', () async {
    await insertRow(
      'refund000001',
      direction: SwapRowDirection.send,
      status: 'expired',
      paymentAddress: null,
    );
    await appDb.customStatement(
      "UPDATE swaps SET refund_address = 'refund-destination', "
      "send_txid = 'lockup-id' WHERE id = 'refund000001'",
    );
    await insertRow(
      'refund000002',
      direction: SwapRowDirection.send,
      status: 'refundable',
    );
    final source = await appDb
        .customSelect('SELECT * FROM swaps ORDER BY id')
        .get();
    final old = BoltzSwapsDatabase(NativeDatabase(migration.standalone));
    try {
      await old.customStatement('DROP TABLE auto_swap');
      await old.customStatement('DROP TABLE legacy_import_receipts');
      await old.customStatement('PRAGMA user_version = 2');
      await old.customStatement(
        "INSERT INTO swap_data_migrations (name,completed_at) "
        "VALUES ('app-db-swaps-v1',1700000000)",
      );
    } finally {
      await old.close();
    }

    await run();

    final admission = await gate.acquire(
      exclusive: false,
      timeout: const Duration(seconds: 2),
    ) as RuntimeAdmission;
    try {
      final opened = await migration.open(admission);
      await opened.fold((store) async {
        final imported = await store.database
            .customSelect('SELECT * FROM swaps ORDER BY id')
            .get();
        expect(imported, hasLength(source.length));
        expect(
          imported.first.data,
          containsPair('refund_address', 'refund-destination'),
        );
        expect(imported.first.data, containsPair('refund_txid', null));
        expect(imported.last.data, containsPair('status', 'refundable'));
        expect([
          for (final row in imported)
            Map.fromEntries(
              row.data.entries.where(
                (entry) => source.first.data.containsKey(entry.key),
              ),
            ),
        ], source.map((row) => row.data));
      }, (_) async => fail('Could not reopen Boltz destination'));
    } finally {
      await admission.close();
    }
  });

  test('runs once and never overwrites what the engine wrote', () async {
    await insertRow('chainSwap001', direction: SwapRowDirection.onchain);
    await run();
    final imported = await rows.fetch('chainSwap001');
    if (imported == null) fail('chain swap was not imported');
    await rows.store(imported.copyWith(status: 'paid'));
    await insertRow('lateRow00001', direction: SwapRowDirection.onchain);

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
          direction: SwapRowDirection.receive,
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
          direction: SwapRowDirection.send,
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
          direction: SwapRowDirection.onchain,
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

/// Only the two tables the cutover reads, with the v16 root's raw columns.
final class _LegacyRoot extends BoltzSwapsDatabase {
  static const version = 16;

  _LegacyRoot(super.executor);

  @override
  int get schemaVersion => version;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await customStatement('''
        CREATE TABLE swaps (
          id TEXT NOT NULL PRIMARY KEY, type TEXT NOT NULL,
          direction TEXT NOT NULL, status TEXT NOT NULL,
          is_testnet INTEGER NOT NULL CHECK (is_testnet IN (0, 1)),
          key_index INTEGER NOT NULL, creation_time INTEGER NOT NULL,
          completion_time INTEGER, receive_wallet_id TEXT, send_wallet_id TEXT,
          invoice TEXT, payment_address TEXT, payment_amount INTEGER,
          receive_address TEXT, receive_txid TEXT, send_txid TEXT,
          preimage TEXT, refund_address TEXT, refund_txid TEXT,
          boltz_fees INTEGER, lockup_fees INTEGER, claim_fees INTEGER,
          refund_fees INTEGER, server_network_fees INTEGER,
          was_direct_payment INTEGER NOT NULL DEFAULT 0 CHECK (was_direct_payment IN (0, 1)),
          recovered INTEGER NOT NULL DEFAULT 0 CHECK (recovered IN (0, 1))
        )
      ''');
      await migrator.createTable(autoSwap);
    },
  );
}

Future<Result<QueryExecutor, LegacyImportFailure>> Function() _executor(
  String path,
) =>
    () async => Ok(NativeDatabase(File(path)));
