import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/utils/utils.dart';

void main() {
  group('btcToSats', () {
    test('converts whole BTC to sats', () {
      expect(Utils.btcToSats('1'), 100000000);
      expect(Utils.btcToSats('0'), 0);
      expect(Utils.btcToSats('21'), 2100000000);
    });

    test('converts BTC with decimals to sats', () {
      expect(Utils.btcToSats('0.00000001'), 1);
      expect(Utils.btcToSats('1.00000001'), 100000001);
      expect(Utils.btcToSats('0.12345678'), 12345678);
      expect(Utils.btcToSats('2.5'), 250000000);
      expect(Utils.btcToSats('0.1'), 10000000);
    });

    test('pads decimals to 8 digits', () {
      expect(Utils.btcToSats('0.1'), 10000000);
      expect(Utils.btcToSats('0.10000000'), 10000000);
    });

    test('throws FormatException for invalid input', () {
      expect(() => Utils.btcToSats('abc'), throwsFormatException);
      expect(() => Utils.btcToSats('1.2.3'), throwsFormatException);
      expect(() => Utils.btcToSats(''), throwsFormatException);
    });

    test('rejects a negative amount instead of flipping its sign', () {
      // int.parse('-0') is 0, so the sign used to be lost entirely and the
      // bounds check, which only rejected sats < 0, passed the positive result.
      expect(() => Utils.btcToSats('-0.9'), throwsFormatException);
      expect(() => Utils.btcToSats('-0.00000001'), throwsFormatException);
      expect(() => Utils.btcToSats('-1'), throwsFormatException);
      expect(() => Utils.btcToSats('-1.5'), throwsFormatException);
    });

    test('rejects an amount it cannot represent instead of paying less', () {
      // Truncating means the payer sends a smaller amount than the request
      // asked for, silently.
      expect(() => Utils.btcToSats('1.999999999'), throwsFormatException);
      expect(() => Utils.btcToSats('0.123456789'), throwsFormatException);
      expect(() => Utils.btcToSats('0.000000019'), throwsFormatException);
    });

    test('rejects malformed but previously accepted amounts', () {
      expect(() => Utils.btcToSats('+5'), throwsFormatException);
      expect(() => Utils.btcToSats('1.'), throwsFormatException);
      expect(() => Utils.btcToSats(' 1'), throwsFormatException);
      expect(() => Utils.btcToSats('1 '), throwsFormatException);
    });

    test('rejects a whole part beyond the supply cap', () {
      // Guards the multiplication itself: a large whole part would overflow
      // 64-bit arithmetic and could wrap into a value the bounds check accepts.
      expect(() => Utils.btcToSats('21000001'), throwsFormatException);
      expect(() => Utils.btcToSats('99999999999'), throwsFormatException);
      expect(Utils.btcToSats('21000000'), 2100000000000000);
    });
  });
}
