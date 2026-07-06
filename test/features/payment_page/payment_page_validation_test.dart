import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('header byte boundaries', () {
    test('accepts 1..=80 bytes and rejects empty / over-cap', () {
      expect(isValidPaymentPageHeader(''), isFalse);
      expect(isValidPaymentPageHeader('a'), isTrue);
      expect(isValidPaymentPageHeader('a' * 80), isTrue);
      expect(isValidPaymentPageHeader('a' * 81), isFalse);
    });

    test('counts UTF-8 bytes, not characters', () {
      // '€' is 3 UTF-8 bytes: 27 euro signs = 81 bytes > 80, but only 27 chars.
      final multibyte = '€' * 27;
      expect(multibyte.length, 27);
      expect(paymentPageByteLength(multibyte), 81);
      expect(isValidPaymentPageHeader(multibyte), isFalse);
      // 26 euro signs = 78 bytes, valid.
      expect(isValidPaymentPageHeader('€' * 26), isTrue);
    });
  });

  group('description byte boundaries', () {
    test('accepts 1..=280 bytes', () {
      expect(isValidPaymentPageDescription(''), isFalse);
      expect(isValidPaymentPageDescription('a' * 280), isTrue);
      expect(isValidPaymentPageDescription('a' * 281), isFalse);
    });
  });

  group('website', () {
    test('empty is allowed (optional)', () {
      expect(isValidPaymentPageWebsite(''), isTrue);
    });

    test('requires an https:// prefix', () {
      expect(isValidPaymentPageWebsite('https://example.com'), isTrue);
      expect(isValidPaymentPageWebsite('http://example.com'), isFalse);
      expect(isValidPaymentPageWebsite('example.com'), isFalse);
    });

    test('rejects over 200 bytes', () {
      final long = 'https://${'a' * 200}.com';
      expect(paymentPageByteLength(long) > paymentPageWebsiteMaxBytes, isTrue);
      expect(isValidPaymentPageWebsite(long), isFalse);
    });
  });

  group('social handles', () {
    test('twitter accepts alphanumerics + underscore, 1-50', () {
      expect(isValidPaymentPageTwitter(''), isTrue);
      expect(isValidPaymentPageTwitter('Bull_Bitcoin1'), isTrue);
      expect(isValidPaymentPageTwitter('has space'), isFalse);
      expect(isValidPaymentPageTwitter('dot.notallowed'), isFalse);
      expect(isValidPaymentPageTwitter('a' * 51), isFalse);
    });

    test('instagram additionally allows dots', () {
      expect(isValidPaymentPageInstagram(''), isTrue);
      expect(isValidPaymentPageInstagram('bull.bitcoin_1'), isTrue);
      expect(isValidPaymentPageInstagram('has space'), isFalse);
      expect(isValidPaymentPageInstagram('a' * 51), isFalse);
    });
  });

  group('SavePaymentPageCommand', () {
    test('flags the first invalid field in form order', () {
      expect(
        const SavePaymentPageCommand(
          header: '',
          description: 'ok',
          displayCurrency: 'CAD',
        ).firstInvalidField(),
        PaymentPageField.header,
      );
      expect(
        const SavePaymentPageCommand(
          header: 'ok',
          description: 'ok',
          displayCurrency: '',
        ).firstInvalidField(),
        PaymentPageField.displayCurrency,
      );
      expect(
        const SavePaymentPageCommand(
          header: 'ok',
          description: 'ok',
          displayCurrency: 'CAD',
          twitter: 'bad handle',
        ).firstInvalidField(),
        PaymentPageField.twitter,
      );
    });

    test('validate throws invalidInput carrying the field name', () {
      expect(
        () => const SavePaymentPageCommand(
          header: '',
          description: 'ok',
          displayCurrency: 'CAD',
        ).validate(),
        throwsA(
          isA<PaymentPageException>()
              .having((e) => e.kind, 'kind', PaymentPageErrorKind.invalidInput)
              .having((e) => e.code, 'code', 'header'),
        ),
      );
    });

    test('a fully valid command passes', () {
      expect(
        const SavePaymentPageCommand(
          header: 'Tip me',
          description: 'Support my work',
          displayCurrency: 'CAD',
          website: 'https://example.com',
          twitter: 'me',
          instagram: 'me.too',
        ).isValid,
        isTrue,
      );
    });
  });

  group('PaymentPage.fromBullnym', () {
    BullnymDonationPage view({String kind = 'payment_page'}) {
      return BullnymDonationPage(
        nym: 'alice',
        header: 'Tip me',
        description: 'Support my work',
        displayCurrency: 'CAD',
        website: null,
        twitter: null,
        instagram: null,
        kind: kind,
        posMode: false,
        enabled: true,
        isArchived: false,
        publicUrl: 'https://bullpay.ca/alice',
      );
    }

    test('maps a payment_page row and derives isActive', () {
      final page = PaymentPage.fromBullnym(view());
      expect(page.nym, 'alice');
      expect(page.isActive, isTrue);
    });

    test('isActive is false when archived', () {
      final page = PaymentPage.fromBullnym(
        BullnymDonationPage(
          nym: 'alice',
          header: 'Tip me',
          description: 'Support my work',
          displayCurrency: 'CAD',
          kind: 'payment_page',
          posMode: false,
          enabled: true,
          isArchived: true,
          publicUrl: 'https://bullpay.ca/alice',
        ),
      );
      expect(page.isActive, isFalse);
    });

    test('refuses a non-payment_page (e.g. pos) row', () {
      expect(
        () => PaymentPage.fromBullnym(view(kind: 'pos')),
        throwsA(
          isA<PaymentPageException>().having(
            (e) => e.kind,
            'kind',
            PaymentPageErrorKind.invalidServerResponse,
          ),
        ),
      );
    });
  });
}
