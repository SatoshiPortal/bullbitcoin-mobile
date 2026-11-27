import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_field_checks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLABE', () {
    test('18 digits with the right check digit is valid', () {
      expect(speiClabeProblem('032180000118359719'), isNull);
      expect(speiClabeProblem(' 032180000118359719 '), isNull);
    });

    test('a wrong last digit is a mistyped CLABE', () {
      expect(
        speiClabeProblem('032180000118359718'),
        SpeiProblem.clabeWrongCheckDigit,
      );
    });

    test('anything but 18 digits is refused', () {
      for (final clabe in [
        '03218000011835971',
        '0321800001183597190',
        '03218000011835971a',
        '032 180 000 118 359 719',
      ]) {
        expect(
          speiClabeProblem(clabe),
          SpeiProblem.clabeNotEighteenDigits,
          reason: clabe,
        );
      }
    });
  });

  test('a SPEI phone is 10 digits', () {
    expect(speiPhoneProblem('5512345678'), isNull);
    expect(speiPhoneProblem('551234567'), SpeiProblem.phoneNotTenDigits);
    expect(speiPhoneProblem('+525512345678'), SpeiProblem.phoneNotTenDigits);
  });

  test('a SPEI debit card is 16 digits', () {
    expect(speiDebitCardProblem('4111111111111111'), isNull);
    expect(
      speiDebitCardProblem('411111111111111'),
      SpeiProblem.debitCardNotSixteenDigits,
    );
    expect(
      speiDebitCardProblem('4111 1111 1111 1111'),
      SpeiProblem.debitCardNotSixteenDigits,
    );
  });

  test('an email needs one @, a dotted domain and no spaces', () {
    expect(emailLooksValid('ada@example.co'), isTrue);
    expect(emailLooksValid('ada@example'), isFalse);
    expect(emailLooksValid('ada example.co'), isFalse);
    expect(emailLooksValid('ada@@example.co'), isFalse);
  });
}
