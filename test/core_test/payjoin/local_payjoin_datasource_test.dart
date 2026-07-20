import 'dart:typed_data';

import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase db;
  late LocalPayjoinDatasource datasource;

  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    datasource = LocalPayjoinDatasource(db: db);
  });

  tearDown(() async => db.close());

  final originalTxId = 'a' * 64;
  final proposalTxId = 'b' * 64;

  PayjoinReceiverModel buildReceiver({
    String? txId,
    String? originalTxIdValue,
    bool isAborted = false,
  }) =>
      PayjoinModel.receiver(
            id: 'r1',
            address: 'bcrt1qaddress',
            isTestnet: true,
            receiver: '[]',
            walletId: 'w1',
            pjUri: 'bitcoin:bcrt1qaddress?pj=https://payjo.in/x',
            maxFeeRateSatPerVb: BigInt.from(10000),
            createdAt: 1700000000,
            expireAfterSec: 86400,
            originalTxBytes: Uint8List.fromList([1, 2, 3]),
            originalTxId: originalTxIdValue,
            amountSat: 5000,
            txId: txId,
            isAborted: isAborted,
          )
          as PayjoinReceiverModel;

  group('fetchByTxId', () {
    test('finds an aborted session by its ORIGINAL transaction id — the only '
        'id that exists on-chain for a fallback broadcast (txId is null, no '
        'proposal was ever broadcast); matching only txId hid the aborted '
        'outcome from the transaction details entirely', () async {
      await datasource.storeReceiver(
        buildReceiver(originalTxIdValue: originalTxId, isAborted: true),
      );

      final found = await datasource.fetchByTxId(originalTxId);

      expect(found, hasLength(1));
      expect(found.single.isAborted, isTrue);
    });

    test('still finds a session by its payjoin transaction id', () async {
      await datasource.storeReceiver(
        buildReceiver(txId: proposalTxId, originalTxIdValue: originalTxId),
      );

      final found = await datasource.fetchByTxId(proposalTxId);

      expect(found, hasLength(1));
    });

    test('returns nothing for an unrelated transaction id', () async {
      await datasource.storeReceiver(
        buildReceiver(txId: proposalTxId, originalTxIdValue: originalTxId),
      );

      final found = await datasource.fetchByTxId('c' * 64);

      expect(found, isEmpty);
    });
  });

  group('fetchAll(onlyUnfinished)', () {
    test('excludes aborted sessions — they must never be resumed', () async {
      await datasource.storeReceiver(
        buildReceiver(originalTxIdValue: originalTxId, isAborted: true),
      );

      final unfinished = await datasource.fetchAll(onlyUnfinished: true);
      final all = await datasource.fetchAll();

      expect(unfinished, isEmpty);
      expect(all, hasLength(1));
    });
  });
}
