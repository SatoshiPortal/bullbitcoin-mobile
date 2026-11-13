import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('converts exact satoshi values in both directions', () {
    for (final sats in ['0', '1', '100000000', '2100000000000000']) {
      final value = BigInt.parse(sats);
      var roundTrip = value;
      for (var index = 0; index < 100; index++) {
        final btc = BullBitcoinAmountText.format(roundTrip, BitcoinUnit.btc);
        expect(BullBitcoinAmountText.parse(btc, BitcoinUnit.btc), value);
        roundTrip =
            BullBitcoinAmountText.parse(btc, BitcoinUnit.btc) ??
            BigInt.from(-1);
      }
      expect(BullBitcoinAmountText.format(value, BitcoinUnit.sats), sats);
    }
    expect(
      BullBitcoinAmountText.format(BigInt.one, BitcoinUnit.btc),
      '0.00000001',
    );
  });

  test('rejects incomplete, negative and overprecise input', () {
    for (final value in ['', '1.', '-1', '0.000000001', '1,1', 'a']) {
      expect(BullBitcoinAmountText.parse(value, BitcoinUnit.btc), isNull);
    }
    expect(BullBitcoinAmountText.parse('1.1', BitcoinUnit.sats), isNull);
  });
}
