import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/src/data/local_payjoin_datasource.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late PayjoinDatabase database;
  late LocalPayjoinDatasource datasource;

  setUp(() {
    database = PayjoinDatabase.forTesting(NativeDatabase.memory());
    datasource = LocalPayjoinDatasource(db: database);
  });

  tearDown(() => database.close());

  final originalTxId = 'a' * 64;
  final proposalTxId = 'b' * 64;

  PayjoinReceiverModel receiver({
    String? transactionId,
    String? originalTransactionId,
    bool aborted = false,
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
            originalTxId: originalTransactionId,
            amountSat: 5000,
            txId: transactionId,
            isAborted: aborted,
          )
          as PayjoinReceiverModel;

  PayjoinSenderModel sender({bool expired = false, bool completed = false}) =>
      PayjoinModel.sender(
            uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
            isTestnet: true,
            sender: '[]',
            walletId: 'w1',
            originalPsbt: 'cHNidP8=',
            originalTxId: originalTxId,
            amountSat: 5000,
            createdAt: 1700000000,
            expireAfterSec: 86400,
            isExpired: expired,
            isCompleted: completed,
          )
          as PayjoinSenderModel;

  group('fetchByTxId', () {
    test('finds an aborted fallback by its original transaction id', () async {
      await datasource.storeReceiver(
        receiver(originalTransactionId: originalTxId, aborted: true),
      );

      final found = await datasource.fetchByTxId(originalTxId);

      expect(found, hasLength(1));
      expect(found.single.isAborted, isTrue);
    });

    test('finds a session by its Payjoin transaction id', () async {
      await datasource.storeReceiver(
        receiver(
          transactionId: proposalTxId,
          originalTransactionId: originalTxId,
        ),
      );

      expect(await datasource.fetchByTxId(proposalTxId), hasLength(1));
      expect(await datasource.fetchByTxId('c' * 64), isEmpty);
    });
  });

  test('unfinished sessions exclude aborted rows', () async {
    await datasource.storeReceiver(
      receiver(originalTransactionId: originalTxId, aborted: true),
    );

    expect(await datasource.fetchAll(onlyUnfinished: true), isEmpty);
    expect(await datasource.fetchAll(), hasLength(1));
  });

  group('replaceExpiredSender', () {
    test('atomically replaces only an unresolved expired session', () async {
      final expired = sender(expired: true);
      await datasource.storeSender(expired);
      final retry = sender().copyWith(
        sender: '["retry"]',
        createdAt: 1800000000,
      );

      expect(await datasource.replaceExpiredSender(retry), isTrue);
      final persisted = await datasource.fetchSender(retry.id);
      expect(persisted?.sender, '["retry"]');
      expect(persisted?.createdAt, 1800000000);
      expect(persisted?.isExpired, isFalse);
    });

    test('does not replace a completed payment', () async {
      final completed = sender(completed: true);
      await datasource.storeSender(completed);

      expect(await datasource.replaceExpiredSender(sender()), isFalse);
      expect((await datasource.fetchSender(completed.id))?.isCompleted, isTrue);
    });
  });

  group('atomic transitions across connections', () {
    late Directory directory;
    late PayjoinDatabase firstDatabase;
    late PayjoinDatabase secondDatabase;
    late LocalPayjoinDatasource first;
    late LocalPayjoinDatasource second;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    tearDownAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    });

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('payjoin-transitions-');
      final file = File('${directory.path}/payjoin.sqlite');
      firstDatabase = PayjoinDatabase.forTesting(NativeDatabase(file));
      first = LocalPayjoinDatasource(db: firstDatabase);
      await firstDatabase.customSelect('SELECT 1').get();
      secondDatabase = PayjoinDatabase.forTesting(NativeDatabase(file));
      second = LocalPayjoinDatasource(db: secondDatabase);
      await secondDatabase.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await secondDatabase.close();
      await firstDatabase.close();
      await directory.delete(recursive: true);
    });

    test('completion wins over stale expiry', () async {
      final model = receiver(
        transactionId: proposalTxId,
        originalTransactionId: originalTxId,
      );
      await first.storeReceiver(model);

      await Future.wait([
        first.markExpired(model.copyWith(isExpired: true)),
        second.markCompleted(model.copyWith(isCompleted: true)),
      ]);

      final persisted = await first.fetchReceiver(model.id);
      expect(persisted?.isCompleted, isTrue);
      expect(persisted?.isExpired, isFalse);
    });

    test('abort wins over a stale sender proposal', () async {
      final model = sender();
      await first.storeSender(model);
      final proposal = model.copyWith(
        sender: '["proposal"]',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        txId: proposalTxId,
      );

      await Future.wait([
        first.recordSenderProposal(proposal),
        second.markAborted(model.copyWith(isAborted: true)),
      ]);

      final persisted = await first.fetchSender(model.id);
      expect(persisted?.isAborted, isTrue);
      expect(persisted?.txId, isNull);
    });

    test('completion wins over abort and records the observed txid', () async {
      final model = receiver(originalTransactionId: originalTxId);
      await first.storeReceiver(model);

      await Future.wait([
        first.markAborted(model.copyWith(isAborted: true)),
        second.markCompleted(
          model.copyWith(isCompleted: true, txId: proposalTxId),
        ),
      ]);

      final persisted = await first.fetchReceiver(model.id);
      expect(persisted?.isCompleted, isTrue);
      expect(persisted?.isAborted, isFalse);
      expect(persisted?.txId, proposalTxId);
    });

    test('a stale abort cannot overwrite completion', () async {
      final model = sender();
      await first.storeSender(model);
      await second.markCompleted(
        model.copyWith(isCompleted: true, txId: proposalTxId),
      );

      expect(await first.markAborted(model.copyWith(isAborted: true)), isFalse);
      final persisted = await first.fetchSender(model.id);
      expect(persisted?.isCompleted, isTrue);
      expect(persisted?.isAborted, isFalse);
      expect(persisted?.txId, proposalTxId);
    });
  });
}
