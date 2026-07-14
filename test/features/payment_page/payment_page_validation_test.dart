import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('header byte boundaries', () {
    test('accepts 1..=80 bytes and rejects empty / over-cap', () {
      expect(isValidPaymentPageHeader(''), isFalse);
      expect(isValidPaymentPageHeader('   '), isFalse);
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

  group('short description boundaries', () {
    test('requires 1..=120 visible characters', () {
      expect(isValidPaymentPageDescription(''), isFalse);
      expect(isValidPaymentPageDescription('   '), isFalse);
      expect(isValidPaymentPageDescription('a' * 120), isTrue);
      expect(isValidPaymentPageDescription('a' * 121), isFalse);
    });

    test('counts composed emoji as user-perceived characters', () {
      final emoji = '😀' * 120;
      expect(paymentPageCharacterLength(emoji), 120);
      expect(paymentPageByteLength(emoji), 480);
      expect(isValidPaymentPageDescription(emoji), isTrue);
      expect(isValidPaymentPageDescription('$emoji😀'), isFalse);
    });

    test('also enforces the server byte safety ceiling', () {
      const family = '👨‍👩‍👧‍👦';
      final withinByteCap = family * 20;
      final overByteCap = family * 21;
      expect(paymentPageCharacterLength(overByteCap), 21);
      expect(paymentPageByteLength(withinByteCap) <= 512, isTrue);
      expect(paymentPageByteLength(overByteCap) > 512, isTrue);
      expect(isValidPaymentPageDescription(withinByteCap), isTrue);
      expect(isValidPaymentPageDescription(overByteCap), isFalse);
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

  group('normalizePaymentPageUrl', () {
    test('prepends https:// to a bare domain', () {
      expect(normalizePaymentPageUrl('aa.com'), 'https://aa.com');
      expect(
        normalizePaymentPageUrl('example.com/path'),
        'https://example.com/path',
      );
    });

    test('leaves an existing http:// or https:// scheme untouched', () {
      expect(
        normalizePaymentPageUrl('https://example.com'),
        'https://example.com',
      );
      expect(
        normalizePaymentPageUrl('http://example.com'),
        'http://example.com',
      );
      // Scheme detection is case-insensitive.
      expect(
        normalizePaymentPageUrl('HTTPS://example.com'),
        'HTTPS://example.com',
      );
    });

    test('empty (or whitespace-only) stays empty', () {
      expect(normalizePaymentPageUrl(''), '');
      expect(normalizePaymentPageUrl('   '), '');
    });

    test('trims surrounding whitespace before prefixing', () {
      expect(normalizePaymentPageUrl('  aa.com  '), 'https://aa.com');
    });
  });

  group('stripHandleAt', () {
    test('strips a single leading @', () {
      expect(stripHandleAt('@handle'), 'handle');
    });

    test('leaves a bare handle untouched', () {
      expect(stripHandleAt('handle'), 'handle');
    });

    test('empty stays empty and strips only one @', () {
      expect(stripHandleAt(''), '');
      expect(stripHandleAt('@@double'), '@double');
    });
  });

  group('optional permanent alias', () {
    test('normalizes once and validates the exact shared-name contract', () {
      expect(normalizePaymentPageAlias('  Shop-21  '), 'shop-21');
      expect(isValidPaymentPageAliasClaim(null), isTrue);
      expect(isValidPaymentPageAliasClaim('shop-21'), isTrue);
      expect(isValidPaymentPageAliasClaim('-shop'), isFalse);
      expect(isValidPaymentPageAliasClaim('pos'), isFalse);
      expect(isValidPaymentPageAliasClaim('a' * 33), isFalse);
    });

    test('an explicit invalid alias is the first invalid field', () {
      const command = SavePaymentPageCommand(
        aliasClaim: 'pos',
        header: 'Tip me',
        description: 'Support my work',
        displayCurrency: 'CAD',
      );
      expect(command.firstInvalidField(), PaymentPageField.alias);
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
    BullnymDonationPage view({String kind = 'payment_page', String? alias}) {
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
        alias: alias,
        publicUrl: alias == null
            ? 'https://bullpay.ca/alice'
            : 'https://bullpay.ca/a/$alias',
      );
    }

    test('maps a payment_page row and derives isActive', () {
      final page = PaymentPage.fromBullnym(view());
      expect(page.nym, 'alice');
      expect(page.isActive, isTrue);
    });

    test('maps the server-owned alias and canonical URL', () {
      final page = PaymentPage.fromBullnym(view(alias: 'shop'));
      expect(page.alias, 'shop');
      expect(page.publicUrl, 'https://bullpay.ca/a/shop');
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
