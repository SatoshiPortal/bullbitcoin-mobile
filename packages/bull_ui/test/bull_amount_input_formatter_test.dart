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

void main() {
  group('BullAmountInputFormatter', () {
    test('derives 8 decimals for BTC', () {
      final formatter = BullAmountInputFormatter('BTC');
      expect(format(formatter, '0.12345678'), '0.12345678');
      expect(format(formatter, '0.123456789'), '0.12345678');
    });

    test('rejects any fraction for sats', () {
      final formatter = BullAmountInputFormatter('sats');
      expect(format(formatter, '1000'), '1000');
      expect(format(formatter, '10.5'), '');
    });

    test('derives 2 decimals for fiat and normalises commas', () {
      final formatter = BullAmountInputFormatter('CAD');
      expect(format(formatter, '12,34'), '12.34');
      expect(format(formatter, '12.345'), '12.34');
    });

    // Regression: the custom-fee tile passes maxDecimals: 2 so a sat/vByte
    // rate can't be typed with more precision than it can store and redisplay.
    // Without the cap the BTC-derived default of 8 would accept "0.12345678",
    // which then snaps to the nearest sat/kwu and redisplays as "0.12" —
    // typed != stored != shown.
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
}
