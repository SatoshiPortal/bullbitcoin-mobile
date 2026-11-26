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
    test('derives 8 decimals for BTC and rejects a 9th', () {
      final formatter = BullAmountInputFormatter('BTC');
      expect(format(formatter, '0.12345678'), '0.12345678');
      expect(format(formatter, '0.123456789'), '');
    });

    test('rejects any fraction for sats', () {
      final formatter = BullAmountInputFormatter('sats');
      expect(format(formatter, '1000'), '1000');
      expect(format(formatter, '10.5'), '');
    });

    test('uses the given precision for fiat and normalises commas', () {
      final cad = BullAmountInputFormatter('CAD');
      expect(format(cad, '12,34'), '12.34');
      expect(format(cad, '12.345'), '');
      final cop = BullAmountInputFormatter('COP', maxDecimals: 0);
      expect(format(cop, '1200'), '1200');
      expect(format(cop, '12.5'), '');
    });

    test('maxDecimals overrides the currency-derived precision', () {
      final capped = BullAmountInputFormatter('BTC', maxDecimals: 2);
      expect(format(capped, '0.12'), '0.12');
      expect(format(capped, '0.123'), '');
      expect(format(capped, '5'), '5');
    });

    test('accepts a leading decimal separator as zero', () {
      final btc = BullAmountInputFormatter('BTC');
      expect(format(btc, '.'), '0.');
      expect(format(btc, ',01'), '0.01');
      expect(format(BullAmountInputFormatter('CAD'), '.5'), '0.5');
      expect(format(BullAmountInputFormatter('sats'), '.01'), '');
    });

    test('keeps the caret after the separator when one is typed first', () {
      final value = BullAmountInputFormatter('BTC').formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '.',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(value.text, '0.');
      expect(value.selection, const TextSelection.collapsed(offset: 2));
    });

    test('never keeps an extra leading zero', () {
      final btc = BullAmountInputFormatter('BTC');
      const zero = TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(
        btc
            .formatEditUpdate(
              zero,
              const TextEditingValue(
                text: '00',
                selection: TextSelection.collapsed(offset: 2),
              ),
            )
            .text,
        '0',
      );
      expect(format(btc, '05'), '5');
      expect(format(btc, '000000'), '0');
      expect(format(BullAmountInputFormatter('sats'), '0001'), '1');
    });

    test('normalises a paste that keeps its value, rejects the rest', () {
      final btc = BullAmountInputFormatter('BTC');
      expect(format(btc, '0,0001'), '0.0001');
      for (final bad in ['-5', '1e5', '1.2.3', '1 000', 'abc', '1\n']) {
        expect(format(btc, bad), '', reason: bad);
      }
    });

    test('caps bitcoin units at 21,000,000 BTC', () {
      final btc = BullAmountInputFormatter('BTC');
      expect(format(btc, '21000000'), '21000000');
      expect(format(btc, '21000000.0'), '21000000.0');
      expect(format(btc, '21000000.1'), '');
      expect(format(btc, '21000001'), '');
      final sats = BullAmountInputFormatter('sats');
      expect(format(sats, '2100000000000000'), '2100000000000000');
      expect(format(sats, '2100000000000001'), '');
      expect(format(BullAmountInputFormatter('CAD'), '99999999'), '99999999');
    });

    test('preserves both ends and direction of a normalized selection', () {
      final value = BullAmountInputFormatter('BTC').formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '00012.34',
          selection: TextSelection(baseOffset: 7, extentOffset: 3),
        ),
      );
      expect(value.text, '12.34');
      expect(
        value.selection,
        const TextSelection(baseOffset: 4, extentOffset: 0),
      );
    });

    test('uses currency precision and keeps rates outside the supply cap', () {
      expect(format(BullAmountInputFormatter('JPY'), '1.1'), '');
      expect(format(BullAmountInputFormatter('KWD'), '1.123'), '1.123');
      expect(
        format(
          BullAmountInputFormatter('sat/vByte', maxDecimals: 2),
          '21000001.25',
        ),
        '21000001.25',
      );
      expect(
        format(
          BullAmountInputFormatter('sats', enforceBitcoinSupply: false),
          '2100000000000001',
        ),
        '2100000000000001',
      );
    });

    test('leaves an IME composition untouched', () {
      final value = BullAmountInputFormatter('BTC').formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '00',
          composing: TextRange(start: 0, end: 2),
        ),
      );
      expect(value.text, '00');
    });
  });
}
