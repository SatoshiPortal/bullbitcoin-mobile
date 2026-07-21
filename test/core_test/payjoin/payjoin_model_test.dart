import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayjoinModel.status derivation', () {
    PayjoinReceiverModel buildReceiver({
      bool isCompleted = false,
      bool isAborted = false,
      bool isExpired = false,
      String? proposalPsbt,
      dynamic originalTxBytes,
    }) =>
        PayjoinModel.receiver(
              id: 'r1',
              address: 'addr',
              isTestnet: true,
              receiver: '[]',
              walletId: 'w1',
              pjUri: 'bitcoin:addr?pj=https://payjo.in/x',
              maxFeeRateSatPerVb: BigInt.from(10000),
              createdAt: 0,
              expireAfterSec: 86400,
              proposalPsbt: proposalPsbt,
              isCompleted: isCompleted,
              isAborted: isAborted,
              isExpired: isExpired,
            )
            as PayjoinReceiverModel;

    test('isCompleted takes priority over everything else', () {
      final model = buildReceiver(
        isCompleted: true,
        isAborted: true,
        isExpired: true,
      );
      expect(model.status, PayjoinStatus.completed);
    });

    test('isAborted takes priority over isExpired', () {
      final model = buildReceiver(isAborted: true, isExpired: true);
      expect(model.status, PayjoinStatus.aborted);
    });

    test('isExpired when neither completed nor aborted', () {
      final model = buildReceiver(isExpired: true);
      expect(model.status, PayjoinStatus.expired);
    });

    test('proposed when a proposal exists and nothing terminal is set', () {
      final model = buildReceiver(proposalPsbt: 'psbt');
      expect(model.status, PayjoinStatus.proposed);
    });

    test('started when nothing has happened yet', () {
      final model = buildReceiver();
      expect(model.status, PayjoinStatus.started);
    });
  });

  group('PayjoinModel.fromReceiverTable/fromSenderTable round-trip '
      'isExpired/isCompleted/isAborted (regression: these used to be silently '
      'dropped on every re-fetch, resetting status to "never resolved")', () {
    test('fromReceiverTable maps the terminal flags from the row', () {
      final row = PayjoinReceiverRow(
        id: 'r1',
        address: 'addr',
        isTestnet: true,
        receiver: '[]',
        walletId: 'w1',
        pjUri: 'bitcoin:addr?pj=https://payjo.in/x',
        maxFeeRateSatPerVb: BigInt.from(10000),
        createdAt: 0,
        expireAfterSec: 86400,
        isExpired: false,
        isCompleted: true,
        isAborted: false,
      );

      final model = PayjoinModel.fromReceiverTable(row);

      expect(model.isCompleted, isTrue);
      expect(model.status, PayjoinStatus.completed);
    });

    test('fromReceiverTable maps isAborted from the row', () {
      final row = PayjoinReceiverRow(
        id: 'r1',
        address: 'addr',
        isTestnet: true,
        receiver: '[]',
        walletId: 'w1',
        pjUri: 'bitcoin:addr?pj=https://payjo.in/x',
        maxFeeRateSatPerVb: BigInt.from(10000),
        createdAt: 0,
        expireAfterSec: 86400,
        isExpired: false,
        isCompleted: false,
        isAborted: true,
      );

      final model = PayjoinModel.fromReceiverTable(row);

      expect(model.isAborted, isTrue);
      expect(model.status, PayjoinStatus.aborted);
    });

    test('fromSenderTable maps the terminal flags from the row', () {
      final row = PayjoinSenderRow(
        uri: 'bitcoin:addr?pj=https://payjo.in/x',
        isTestnet: true,
        sender: '[]',
        walletId: 'w1',
        originalPsbt: 'psbt',
        originalTxId: 'a' * 64,
        amountSat: 10000,
        createdAt: 0,
        expireAfterSec: 86400,
        isExpired: false,
        isCompleted: true,
        isAborted: false,
      );

      final model = PayjoinModel.fromSenderTable(row);

      expect(model.isCompleted, isTrue);
      expect(model.status, PayjoinStatus.completed);
    });
  });
}
