import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const paymentTxid =
    '0000000000000000000000000000000000000000000000000000000000000def';

SpPayment buildPayment({String txid = paymentTxid, int? height = 800000}) {
  return SpPayment(
    txid: txid,
    direction: SpPaymentDirection.receive,
    status: SpPaymentStatus.verified,
    amountSat: Sats.fromInt(2500),
    feeSat: Sats.fromInt(300),
    height: height,
    timestamp: BigInt.from(1700000000),
    hasSpOutput: true,
  );
}

void main() {
  group('SpPayment invariants', () {
    test('accepts a well formed payment', () {
      final payment = buildPayment();

      expect(payment.txid, paymentTxid);
      expect(payment.direction, SpPaymentDirection.receive);
      expect(payment.status, SpPaymentStatus.verified);
      expect(payment.amountSat, Sats.fromInt(2500));
      expect(payment.feeSat, Sats.fromInt(300));
      expect(payment.height, 800000);
      expect(payment.timestamp, BigInt.from(1700000000));
      expect(payment.hasSpOutput, isTrue);
    });

    test('rejects an empty txid', () {
      expect(() => buildPayment(txid: ''), throwsA(isA<ArgumentError>()));
    });

    test('rejects a negative height', () {
      expect(() => buildPayment(height: -1), throwsA(isA<ArgumentError>()));
    });

    test('accepts a null height for an unconfirmed payment', () {
      expect(buildPayment(height: null).height, isNull);
    });

    test('hasSpOutput defaults to false', () {
      final payment = SpPayment(
        txid: paymentTxid,
        direction: SpPaymentDirection.send,
        status: SpPaymentStatus.unconfirmed,
        amountSat: Sats.fromInt(10),
      );

      expect(payment.hasSpOutput, isFalse);
      expect(payment.feeSat, isNull);
      expect(payment.height, isNull);
      expect(payment.timestamp, isNull);
    });
  });

  group('SpPayment.copyWith', () {
    test('flips hasSpOutput and keeps every other field', () {
      final copy = buildPayment().copyWith(hasSpOutput: false);

      expect(copy.hasSpOutput, isFalse);
      expect(copy.txid, paymentTxid);
      expect(copy.direction, SpPaymentDirection.receive);
      expect(copy.status, SpPaymentStatus.verified);
      expect(copy.amountSat, Sats.fromInt(2500));
      expect(copy.feeSat, Sats.fromInt(300));
      expect(copy.height, 800000);
      expect(copy.timestamp, BigInt.from(1700000000));
    });

    test('keeps the current hasSpOutput when the argument is omitted', () {
      expect(buildPayment().copyWith().hasSpOutput, isTrue);
    });
  });
}
