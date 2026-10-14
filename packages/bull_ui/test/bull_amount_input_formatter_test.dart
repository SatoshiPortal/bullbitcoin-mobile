import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [formatter] over [input] as if the whole string had just been typed
/// into an empty field, and returns the text the field would end up holding.
String format(BullAmountInputFormatter formatter, String input) {
  return formatter
      .formatEditUpdate(
        const TextEditingValue(text: ''),
        TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        ),
      )
      .text;
}

/// Types [keys] one at a time at the cursor, the way a keyboard does, and
/// returns the field's final value.
TextEditingValue type(
  BullAmountInputFormatter formatter,
  String keys, {
  TextEditingValue start = TextEditingValue.empty,
}) {
  var value = start;
  for (final key in keys.split('')) {
    final cursor = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    final typed = TextEditingValue(
      text:
          value.text.substring(0, cursor) + key + value.text.substring(cursor),
      selection: TextSelection.collapsed(offset: cursor + 1),
    );
    value = formatter.formatEditUpdate(value, typed);
  }
  return value;
}

/// Presses backspace with the cursor at [cursor] in [value].
TextEditingValue backspace(
  BullAmountInputFormatter formatter,
  TextEditingValue value,
  int cursor,
) {
  final deleted = TextEditingValue(
    text: value.text.substring(0, cursor - 1) + value.text.substring(cursor),
    selection: TextSelection.collapsed(offset: cursor - 1),
  );
  return formatter.formatEditUpdate(
    value.copyWith(selection: TextSelection.collapsed(offset: cursor)),
    deleted,
  );
}

void main() {
  tearDown(() => BullNumberFormat.useLanguage('en'));

  group('BullAmountInputFormatter', () {
    test('derives 8 decimals for BTC', () {
      final formatter = BullAmountInputFormatter('BTC');
      expect(format(formatter, '0.12345678'), '0.12345678');
      expect(format(formatter, '0.123456789'), '0.12345678');
    });

    test('rejects any fraction for sats', () {
      final formatter = BullAmountInputFormatter('sats');
      expect(format(formatter, '1000'), '1,000');
      expect(format(formatter, '10.5'), '');
    });

    test('derives 2 decimals for fiat and normalises commas', () {
      final formatter = BullAmountInputFormatter('CAD');
      expect(format(formatter, '12,34'), '12.34');
      expect(format(formatter, '12.345'), '12.34');
    });

    group('while typing', () {
      test('groups thousands while typing', () {
        final formatter = BullAmountInputFormatter('sats');
        final value = type(formatter, '1234567');
        expect(value.text, '1,234,567');
        expect(value.selection.end, value.text.length);
      });

      test('takes either , or . from the keyboard as the decimal key', () {
        final formatter = BullAmountInputFormatter('BTC');
        expect(type(formatter, '1234,5').text, '1,234.5');
        expect(type(formatter, '1234.5').text, '1,234.5');
        expect(type(formatter, '0,').text, '0.');
      });

      test('writes French separators while typing', () {
        BullNumberFormat.useLanguage('fr');
        final formatter = BullAmountInputFormatter('BTC');
        expect(type(formatter, '1234.5').text, '1\u00A0234,5');
        expect(type(formatter, '1234,50').text, '1\u00A0234,50');
        expect(type(formatter, '0,').text, '0,');
      });

      test('keeps the cursor next to a digit typed in the middle', () {
        final formatter = BullAmountInputFormatter('sats');
        final start = type(formatter, '1234');
        // Cursor after "1,2": typing 9 gives 12,934 with the cursor after 9.
        final value = type(
          formatter,
          '9',
          start: start.copyWith(
            selection: const TextSelection.collapsed(offset: 3),
          ),
        );
        expect(value.text, '12,934');
        expect(value.selection.end, 4);
      });

      test(
        'backspace over a thousands separator deletes the digit before it',
        () {
          final formatter = BullAmountInputFormatter('sats');
          final value = backspace(formatter, type(formatter, '1234'), 2);
          expect(value.text, '234');
          expect(value.selection.end, 0);
        },
      );

      test(
        'forward delete over a thousands separator deletes the digit after it',
        () {
          final formatter = BullAmountInputFormatter('sats');
          final start = type(formatter, '1234');
          // Cursor before the separator in "1,234"; delete removes the ",".
          final deleted = formatter.formatEditUpdate(
            start.copyWith(selection: const TextSelection.collapsed(offset: 1)),
            const TextEditingValue(
              text: '1234',
              selection: TextSelection.collapsed(offset: 1),
            ),
          );
          expect(deleted.text, '134');
          expect(deleted.selection.end, 1);
        },
      );

      test('deleting a selected thousands separator keeps the number', () {
        final formatter = BullAmountInputFormatter('sats');
        final start = type(formatter, '1234');
        final deleted = formatter.formatEditUpdate(
          start.copyWith(
            selection: const TextSelection(baseOffset: 1, extentOffset: 2),
          ),
          const TextEditingValue(
            text: '1234',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        expect(deleted.text, '1,234');
      });

      test('reads a pasted thousand with a single separator by language', () {
        expect(format(BullAmountInputFormatter('CAD'), '1,234'), '1,234');
        expect(format(BullAmountInputFormatter('CAD'), '1,5'), '1.5');
        expect(format(BullAmountInputFormatter('BTC'), '1.234'), '1.234');

        BullNumberFormat.useLanguage('fr');
        expect(format(BullAmountInputFormatter('CAD'), '1.234'), '1\u00A0234');
        expect(format(BullAmountInputFormatter('BTC'), '1,234'), '1,234');
      });

      test('reads a pasted amount with grouping', () {
        final formatter = BullAmountInputFormatter('CAD');
        expect(format(formatter, '1,234.56'), '1,234.56');
        expect(format(formatter, '1 234,56'), '1,234.56');
        expect(format(formatter, '1,234,567'), '1,234,567');
      });

      test('rejects a second decimal separator', () {
        final formatter = BullAmountInputFormatter('BTC');
        expect(type(formatter, '1.2.').text, '1.2');
      });
    });

    // Regression: the custom-fee tile passes maxDecimals: 2 so a sat/vByte
    // rate can't be typed with more precision than it can store and
    // redisplay. Without the cap the BTC-derived default of 8 would accept
    // "0.12345678", which then snaps to the nearest sat/kwu and redisplays
    // as "0.12" — typed != stored != shown.
    test('maxDecimals overrides the currency-derived precision', () {
      final capped = BullAmountInputFormatter('BTC', maxDecimals: 2);
      expect(format(capped, '0.12345678'), '0.12');
      expect(format(capped, '0.12'), '0.12');
      expect(format(capped, '5'), '5');
    });

    test('maxDecimals of 0 rejects a fractional rate outright', () {
      final whole = BullAmountInputFormatter('BTC', maxDecimals: 0);
      expect(format(whole, '7'), '7');
      expect(format(whole, '7.5'), '');
    });
  });

  group('BullAmountController', () {
    test('shows the raw amount formatted and reads it back raw', () {
      BullNumberFormat.useLanguage('fr');
      final controller = BullAmountController(amount: '1234.5');
      expect(controller.text, '1\u00A0234,5');
      expect(controller.amount, '1234.5');

      controller.amount = '0.';
      expect(controller.text, '0,');
      expect(controller.amount, '0.');
      expect(controller.selection.end, 2);
      controller.dispose();
    });

    test(
      'keeps the amount and rewrites the text when the language changes',
      () {
        final controller = BullAmountController(amount: '1234.5');
        expect(controller.text, '1,234.5');

        BullNumberFormat.useLanguage('fr');
        expect(controller.text, '1\u00A0234,5');
        expect(controller.amount, '1234.5');

        BullNumberFormat.useLanguage('en');
        expect(controller.text, '1,234.5');
        expect(controller.amount, '1234.5');
        controller.dispose();
      },
    );

    test('tracks the amount as the field is edited', () {
      final controller = BullAmountController();
      final formatter = BullAmountInputFormatter('sats');
      controller.value = type(formatter, '1234567');
      expect(controller.amount, '1234567');
      controller.clear();
      expect(controller.amount, '');
      controller.dispose();
    });
  });
}
