import 'package:bb_mobile/features/sp/data/sp_payment_join.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  group('SpPaymentJoin.markSpOutputs', () {
    SpPayment payment(String txid) => SpPayment(
      txid: txid,
      direction: SpPaymentDirection.receive,
      status: SpPaymentStatus.unconfirmed,
      amountSat: Sats.fromInt(1),
    );

    SpCoin coin(String txid, SpCoinSource source) => SpCoin(
      source: source,
      outpoint: (txId: txid, vout: 0),
      amountSat: Sats.fromInt(1),
      status: SpCoinStatus.unspent,
    );

    test('flags a payment whose txid has an SP coin', () {
      final result = SpPaymentJoin.markSpOutputs(
        [payment('aa')],
        [coin('aa', SpCoinSource.sp)],
      );

      expect(result.single.hasSpOutput, isTrue);
    });

    test('does not flag a payment whose coin is on another sub-account', () {
      final result = SpPaymentJoin.markSpOutputs(
        [payment('aa')],
        [coin('aa', SpCoinSource.taproot)],
      );

      expect(result.single.hasSpOutput, isFalse);
    });

    test('does not flag a payment with no matching coin', () {
      final result = SpPaymentJoin.markSpOutputs(
        [payment('aa')],
        [coin('bb', SpCoinSource.sp)],
      );

      expect(result.single.hasSpOutput, isFalse);
    });
  });
}
