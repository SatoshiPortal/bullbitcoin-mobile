import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => BullNumberFormat.useLanguage('en'));

  group('BullNumberFormat', () {
    test('writes a comma between thousands and a dot before decimals', () {
      BullNumberFormat.useLanguage('en');

      expect(BullNumberFormat.decimal(7123.51), '7,123.51');
      expect(BullNumberFormat.decimal(1234567), '1,234,567');
    });

    test('writes a no-break space and a comma in French', () {
      BullNumberFormat.useLanguage('fr');

      expect(BullNumberFormat.decimal(7123.51), '7\u00A0123,51');
      expect(BullNumberFormat.decimal(1234567.5), '1\u00A0234\u00A0567,5');
    });

    test('uses the non-French style for every other language', () {
      for (final language in ['de', 'es', 'it', 'pt', 'ru', 'uk', 'ar']) {
        BullNumberFormat.useLanguage(language);

        expect(BullNumberFormat.decimal(7123.51), '7,123.51', reason: language);
      }
    });

    test('pads to minDecimals and trims past it up to maxDecimals', () {
      expect(
        BullNumberFormat.decimal(5, minDecimals: 2, maxDecimals: 2),
        '5.00',
      );
      expect(BullNumberFormat.decimal(0.5, maxDecimals: 8), '0.5');
      expect(
        BullNumberFormat.decimal(0.0000001, minDecimals: 8, maxDecimals: 8),
        '0.00000010',
      );
      expect(BullNumberFormat.decimal(1234.5678, maxDecimals: 0), '1,235');
    });

    test('leaves thousands ungrouped when grouping is off', () {
      expect(
        BullNumberFormat.decimal(1234.5, maxDecimals: 8, grouping: false),
        '1234.5',
      );

      BullNumberFormat.useLanguage('fr');
      expect(
        BullNumberFormat.decimal(1234.5, maxDecimals: 8, grouping: false),
        '1234,5',
      );
    });
  });
}
