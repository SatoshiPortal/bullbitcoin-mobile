import 'package:bb_mobile/features/sp/data/mappers/sp_payment_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

bwk.SpPaymentView buildView({
  bwk.SpPaymentDirection direction = bwk.SpPaymentDirection.receive,
  bwk.SpPaymentStatus status = bwk.SpPaymentStatus.verified,
  BigInt? feeSat,
  int? height = 800000,
  BigInt? timestamp,
}) {
  return bwk.SpPaymentView(
    txid: 'aabbcc',
    direction: direction,
    status: status,
    amountSat: BigInt.from(4321),
    feeSat: feeSat,
    height: height,
    timestamp: timestamp,
  );
}

void main() {
  group('SpPaymentMapper.toDomain', () {
    test('maps every field of a confirmed receive', () {
      final payment = SpPaymentMapper.toDomain(
        buildView(feeSat: BigInt.from(150), timestamp: BigInt.from(1700000000)),
      );

      expect(payment.txid, 'aabbcc');
      expect(payment.direction, SpPaymentDirection.receive);
      expect(payment.status, SpPaymentStatus.verified);
      expect(payment.amountSat, Sats.fromInt(4321));
      expect(payment.feeSat, Sats.fromInt(150));
      expect(payment.height, 800000);
      expect(payment.timestamp, BigInt.from(1700000000));
    });

    test('keeps a null fee null instead of defaulting it to zero', () {
      expect(SpPaymentMapper.toDomain(buildView()).feeSat, isNull);
    });

    test('keeps a null height and timestamp for an unconfirmed payment', () {
      final payment = SpPaymentMapper.toDomain(
        buildView(status: bwk.SpPaymentStatus.unconfirmed, height: null),
      );

      expect(payment.height, isNull);
      expect(payment.timestamp, isNull);
      expect(payment.status, SpPaymentStatus.unconfirmed);
    });

    test('maps every direction', () {
      expect(
        SpPaymentMapper.toDomain(
          buildView(direction: bwk.SpPaymentDirection.receive),
        ).direction,
        SpPaymentDirection.receive,
      );
      expect(
        SpPaymentMapper.toDomain(
          buildView(direction: bwk.SpPaymentDirection.send),
        ).direction,
        SpPaymentDirection.send,
      );
      expect(
        SpPaymentMapper.toDomain(
          buildView(direction: bwk.SpPaymentDirection.selfSend),
        ).direction,
        SpPaymentDirection.selfSend,
      );
    });

    test('maps every status', () {
      expect(
        SpPaymentMapper.toDomain(
          buildView(status: bwk.SpPaymentStatus.unconfirmed),
        ).status,
        SpPaymentStatus.unconfirmed,
      );
      expect(
        SpPaymentMapper.toDomain(
          buildView(status: bwk.SpPaymentStatus.confirmedUnverified),
        ).status,
        SpPaymentStatus.confirmedUnverified,
      );
      expect(
        SpPaymentMapper.toDomain(
          buildView(status: bwk.SpPaymentStatus.verified),
        ).status,
        SpPaymentStatus.verified,
      );
      expect(
        SpPaymentMapper.toDomain(
          buildView(status: bwk.SpPaymentStatus.verifyFailed),
        ).status,
        SpPaymentStatus.verifyFailed,
      );
    });

    test('hasSpOutput starts false, the coin set decides it later', () {
      expect(SpPaymentMapper.toDomain(buildView()).hasSpOutput, isFalse);
    });
  });
}
