import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('speiClabeProblem', () {
    for (final clabe in [
      '002010077777777771',
      '032180000118359719',
      '646180110400000007',
      ' 002010077777777771 ',
    ]) {
      test('$clabe is valid', () => expect(speiClabeProblem(clabe), isNull));
    }

    for (final clabe in [
      '',
      '00201007777777777',
      '0020100777777777711',
      '00201007777777777a',
      '0020 1007777777777',
    ]) {
      test('"$clabe" is not 18 digits', () {
        expect(speiClabeProblem(clabe), SpeiProblem.clabeNotEighteenDigits);
      });
    }

    test('a wrong last digit fails the check digit', () {
      expect(
        speiClabeProblem('002010077777777772'),
        SpeiProblem.clabeWrongCheckDigit,
      );
      expect(
        speiClabeProblem('012180001234567897'),
        SpeiProblem.clabeWrongCheckDigit,
      );
    });

    test('a check digit of 10 wraps to 0', () {
      // The first 17 digits sum to a multiple of 10.
      expect(speiClabeProblem('000000000000000000'), isNull);
    });
  });

  group('speiPhoneProblem', () {
    test('10 digits are valid', () {
      expect(speiPhoneProblem('5512345678'), isNull);
    });
    for (final phone in ['', '551234567', '55123456789', '+525512345678']) {
      test('"$phone" is not 10 digits', () {
        expect(speiPhoneProblem(phone), SpeiProblem.phoneNotTenDigits);
      });
    }
  });

  group('speiDebitCardProblem', () {
    test('16 digits are valid', () {
      expect(speiDebitCardProblem('4111111111111111'), isNull);
    });
    for (final card in [
      '',
      '411111111111111',
      '41111111111111112',
      '4111 1111',
    ]) {
      test('"$card" is not 16 digits', () {
        expect(
          speiDebitCardProblem(card),
          SpeiProblem.debitCardNotSixteenDigits,
        );
      });
    }
  });

  group('emailLooksValid', () {
    test('an address is valid', () {
      expect(emailLooksValid('ada@example.com'), isTrue);
    });
    for (final email in [
      '',
      'ada',
      'ada@example',
      'a da@example.com',
      'a@b@c.co',
    ]) {
      test('"$email" is not an address', () {
        expect(emailLooksValid(email), isFalse);
      });
    }
  });

  group('a new SPEI recipient with a bad field is not built', () {
    for (final input in [
      const RecipientDetailsInput(
        recipientType: RecipientType.speiClabeMxn,
        name: 'Ada',
        clabe: '002010077777777772',
      ),
      const RecipientDetailsInput(
        recipientType: RecipientType.speiSmsMxn,
        name: 'Ada',
        institutionCode: '40002',
        phone: '55123',
      ),
      const RecipientDetailsInput(
        recipientType: RecipientType.speiCardMxn,
        name: 'Ada',
        institutionCode: '40002',
        debitcard: '4111',
      ),
    ]) {
      test(input.recipientType.name, () {
        expect(input.tryToDomain(), isNull);
        // A recipient the server already has is listed as it is.
        expect(input.toStoredDomain().type, input.recipientType);
      });
    }
  });
}
