import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
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

  PayjoinSenderModel buildSender({
    bool isExpired = false,
    bool isCompleted = false,
  }) =>
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
            isExpired: isExpired,
            isCompleted: isCompleted,
          )
          as PayjoinSenderModel;

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

  group('replaceExpiredSender', () {
    test('atomically replaces only an unresolved expired session', () async {
      final expired = buildSender(isExpired: true);
      await datasource.storeSender(expired);
      final retry = buildSender().copyWith(
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
      final completed = buildSender(isCompleted: true);
      await datasource.storeSender(completed);

      expect(await datasource.replaceExpiredSender(buildSender()), isFalse);
      expect((await datasource.fetchSender(completed.id))?.isCompleted, isTrue);
    });
  });

  group('atomic transitions across connections', () {
    late Directory tempDirectory;
    late SqliteDatabase firstDb;
    late SqliteDatabase secondDb;
    late LocalPayjoinDatasource first;
    late LocalPayjoinDatasource second;

    setUpAll(() {
      // Multiple independent connections are the subject of these tests.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    tearDownAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    });

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'payjoin-transitions-',
      );
      final file = File('${tempDirectory.path}/payjoin.sqlite');
      firstDb = SqliteDatabase(NativeDatabase(file));
      first = LocalPayjoinDatasource(db: firstDb);
      // Open and migrate the first connection before opening the second one.
      await firstDb.customSelect('SELECT 1').get();
      secondDb = SqliteDatabase(NativeDatabase(file));
      second = LocalPayjoinDatasource(db: secondDb);
      await secondDb.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await secondDb.close();
      await firstDb.close();
      await tempDirectory.delete(recursive: true);
    });

    test('a stale expiry cannot overwrite completion', () async {
      final receiver = buildReceiver(
        txId: proposalTxId,
        originalTxIdValue: originalTxId,
      );
      await first.storeReceiver(receiver);

      await Future.wait([
        first.markExpired(receiver.copyWith(isExpired: true)),
        second.markCompleted(receiver.copyWith(isCompleted: true)),
      ]);

      final persisted = await first.fetchReceiver(receiver.id);
      expect(persisted?.isCompleted, isTrue);
      expect(persisted?.isExpired, isFalse);
    });

    test('a stale sender proposal cannot overwrite an abort', () async {
      final sender =
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
              )
              as PayjoinSenderModel;
      await first.storeSender(sender);
      final proposal = sender.copyWith(
        sender: '["proposal"]',
        proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        txId: proposalTxId,
      );

      await Future.wait([
        first.recordSenderProposal(proposal),
        second.markAborted(sender.copyWith(isAborted: true)),
      ]);

      final persisted = await first.fetchSender(sender.id);
      expect(persisted?.isAborted, isTrue);
      expect(persisted?.txId, isNull);
    });

    test(
      'completion wins over an abort and records the observed txid',
      () async {
        final receiver = buildReceiver(originalTxIdValue: originalTxId);
        await first.storeReceiver(receiver);

        await Future.wait([
          first.markAborted(receiver.copyWith(isAborted: true)),
          second.markCompleted(
            receiver.copyWith(isCompleted: true, txId: proposalTxId),
          ),
        ]);

        final persisted = await first.fetchReceiver(receiver.id);
        expect(persisted?.isCompleted, isTrue);
        expect(persisted?.isAborted, isFalse);
        expect(persisted?.txId, proposalTxId);
      },
    );

    test('a stale abort cannot overwrite completion', () async {
      final sender =
          PayjoinModel.sender(
                uri: 'bitcoin:tb1qsender2?pj=https://payjo.in',
                isTestnet: true,
                sender: '[]',
                walletId: 'w1',
                originalPsbt: 'cHNidP8=',
                originalTxId: originalTxId,
                amountSat: 5000,
                createdAt: 1700000000,
                expireAfterSec: 86400,
              )
              as PayjoinSenderModel;
      await first.storeSender(sender);

      await second.markCompleted(
        sender.copyWith(isCompleted: true, txId: proposalTxId),
      );
      final applied = await first.markAborted(sender.copyWith(isAborted: true));

      expect(applied, isFalse);
      final persisted = await first.fetchSender(sender.id);
      expect(persisted?.isCompleted, isTrue);
      expect(persisted?.isAborted, isFalse);
      expect(persisted?.txId, proposalTxId);
    });
  });
}
