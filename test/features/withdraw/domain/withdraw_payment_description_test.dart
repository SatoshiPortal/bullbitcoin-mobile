import 'package:bb_mobile/features/withdraw/domain/withdraw_payment_description.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WithdrawPaymentDescription', () {
    test('removes risky words case-insensitively and normalizes spaces', () {
      expect(
        WithdrawPaymentDescription.sanitize('Invoice for BTC crypto tools'),
        'Invoice for tools',
      );
    });

    test('only removes whole risky words', () {
      expect(
        WithdrawPaymentDescription.sanitize('bitter toolbox'),
        'bitter toolbox',
      );
    });

    test(
      'allows an empty description or one with at least five characters',
      () {
        expect(WithdrawPaymentDescription.isValid(''), isTrue);
        expect(WithdrawPaymentDescription.isValid('four'), isFalse);
        expect(WithdrawPaymentDescription.isValid('five!'), isTrue);
      },
    );
  });
}
