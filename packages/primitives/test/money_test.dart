import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  group('Sats', () {
    test('rejects negative amounts', () {
      expect(() => Sats(BigInt.from(-1)), throwsArgumentError);
    });

    test('compares by satoshi value', () {
      expect(Sats.fromInt(1).compareTo(Sats.fromInt(2)), isNegative);
      expect(Sats.fromInt(2), Sats(BigInt.two));
    });
  });

  group('FeeRate', () {
    test('rejects non-positive and non-finite values', () {
      expect(() => FeeRate(0), throwsArgumentError);
      expect(() => FeeRate(double.infinity), throwsArgumentError);
    });

    test('accepts fractional satoshis per virtual byte', () {
      expect(FeeRate(1.5).satsPerVbyte, 1.5);
    });
  });
}
