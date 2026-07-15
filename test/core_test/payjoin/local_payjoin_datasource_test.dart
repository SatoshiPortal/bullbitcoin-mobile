import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteDatabase db;
  late LocalPayjoinDatasource datasource;

  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    datasource = LocalPayjoinDatasource(db: db);
  });

  tearDown(() async => db.close());

  PayjoinSenderModel sender({
    required String uri,
    required String originalTxId,
    String? txId,
  }) =>
      PayjoinModel.sender(
            uri: uri,
            isTestnet: true,
            sender: '[]',
            walletId: 'w1',
            originalPsbt: 'cHNidP8=',
            originalTxId: originalTxId,
            amountSat: 50000,
            createdAt: 1750000000,
            expireAfterSec: 60,
            txId: txId,
          )
          as PayjoinSenderModel;

  PayjoinReceiverModel receiver({
    required String id,
    String? originalTxId,
    String? txId,
  }) =>
      PayjoinModel.receiver(
            id: id,
            address: 'tb1qreceiver',
            isTestnet: true,
            receiver: '[]',
            walletId: 'w1',
            pjUri: 'bitcoin:tb1qreceiver?pj=https://payjo.in',
            maxFeeRateSatPerVb: BigInt.from(10000),
            createdAt: 1750000000,
            expireAfterSec: 60,
            originalTxId: originalTxId,
            txId: txId,
          )
          as PayjoinReceiverModel;

  group('LocalPayjoinDatasource.fetchByTxId', () {
    test('matches a sender by its payjoin txId', () async {
      await datasource.storeSender(
        sender(
          uri: 'bitcoin:tb1qa?pj=https://payjo.in',
          originalTxId: 'orig-a',
          txId: 'payjoin-a',
        ),
      );

      final found = await datasource.fetchByTxId('payjoin-a');

      expect(found, hasLength(1));
    });

    test(
      'matches a sender by its ORIGINAL txId — a fallback-completed session '
      'has txId deliberately cleared, so the transaction that actually hit '
      'the chain is only findable through originalTxId (without this the '
      'fallback tx details lost all payjoin context)',
      () async {
        await datasource.storeSender(
          sender(
            uri: 'bitcoin:tb1qb?pj=https://payjo.in',
            originalTxId: 'orig-b',
          ),
        );

        final found = await datasource.fetchByTxId('orig-b');

        expect(found, hasLength(1));
        expect((found.single as PayjoinSenderModel).originalTxId, 'orig-b');
      },
    );

    test('matches a receiver by its ORIGINAL txId', () async {
      await datasource.storeReceiver(
        receiver(id: 'recv-1', originalTxId: 'orig-c'),
      );

      final found = await datasource.fetchByTxId('orig-c');

      expect(found, hasLength(1));
      expect((found.single as PayjoinReceiverModel).id, 'recv-1');
    });

    test('does not match unrelated sessions', () async {
      await datasource.storeSender(
        sender(
          uri: 'bitcoin:tb1qd?pj=https://payjo.in',
          originalTxId: 'orig-d',
          txId: 'payjoin-d',
        ),
      );
      await datasource.storeReceiver(
        receiver(id: 'recv-2', originalTxId: 'orig-e', txId: 'payjoin-e'),
      );

      final found = await datasource.fetchByTxId('some-other-txid');

      expect(found, isEmpty);
    });
  });
}
