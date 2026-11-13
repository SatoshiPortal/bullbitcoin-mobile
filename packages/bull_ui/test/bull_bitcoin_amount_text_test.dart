import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts exact satoshi values in both directions', () {
    for (final sats in ['0', '1', '100000000', '2100000000000000']) {
      final value = BigInt.parse(sats);
      var roundTrip = value;
      for (var index = 0; index < 100; index++) {
        final btc = BullBitcoinAmountText.format(roundTrip, 'BTC');
        expect(BullBitcoinAmountText.parse(btc, 'BTC'), value);
        roundTrip = BullBitcoinAmountText.parse(btc, 'BTC') ?? BigInt.from(-1);
      }
      expect(BullBitcoinAmountText.format(value, 'sats'), sats);
    }
    expect(BullBitcoinAmountText.format(BigInt.one, 'BTC'), '0.00000001');
  });

  test('rejects incomplete, negative and overprecise input', () {
    for (final value in ['', '1.', '-1', '0.000000001', '1,1', 'a']) {
      expect(BullBitcoinAmountText.parse(value, 'BTC'), isNull);
    }
    expect(BullBitcoinAmountText.parse('1.1', 'sats'), isNull);
  });
}
