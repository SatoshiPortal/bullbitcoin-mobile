import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test(
    'fiat display rounds decimal half cents without a double intermediate',
    () {
      expect(Sats.fromInt(1249580).toFiatText(125000, decimals: 2), '1561.98');
      expect(Sats.fromInt(1).toFiatText(500000, decimals: 2), '0.01');
      expect(Sats.fromInt(1).toFiatText(125000, decimals: 2), '0.00');
      expect(Sats.fromInt(100000000).toFiatText(125000, decimals: 0), '125000');
      expect(Sats.fromInt(1).toFiatText(0, decimals: 2), isNull);
    },
  );

  test(
    'bitcoin text preserves every satoshi over repeated representations',
    () {
      for (final digits in ['0', '1', '100000000', '2100000000000000']) {
        final original = BigInt.parse(digits);
        var amount = Sats(original);
        for (var i = 0; i < 100; i++) {
          final text = amount.toBitcoinText(BitcoinUnit.btc);
          final parsed = Sats.tryParseBitcoin(text, BitcoinUnit.btc);
          expect(parsed?.value, original);
          if (parsed == null) fail('A formatted bitcoin amount must parse');
          amount = parsed;
        }
        expect(amount.toBitcoinText(BitcoinUnit.sats), digits);
      }
      expect(Sats(BigInt.one).toBitcoinText(BitcoinUnit.btc), '0.00000001');
    },
  );

  test(
    'bitcoin parsing rejects incomplete, truncated and out-of-supply input',
    () {
      for (final text in [
        '',
        '1.',
        '-1',
        '0.000000001',
        '1,1',
        'a',
        '1\n',
        '21000000.00000001',
      ]) {
        expect(
          Sats.tryParseBitcoin(text, BitcoinUnit.btc),
          isNull,
          reason: text,
        );
      }
      for (final text in ['1.1', '1\n', '2100000000000001']) {
        expect(
          Sats.tryParseBitcoin(text, BitcoinUnit.sats),
          isNull,
          reason: text,
        );
      }
    },
  );

  test('fiat conversion rounds decimal half-satoshi ties up exactly', () {
    expect(Sats.tryFromFiat('0.15', 80000)?.value, BigInt.from(188));
    expect(Sats.tryFromFiat('31.25', 125000)?.value, BigInt.from(25000));
    expect(Sats.tryFromFiat('12.50', 125000)?.value, BigInt.from(10000));
    expect(Sats.tryFromFiat('0.01', 2000000)?.value, BigInt.one);
    expect(Sats.tryFromFiat('0.00', 80000)?.value, BigInt.zero);
    expect(Sats.tryFromFiat('1', 1e-7)?.value, BigInt.from(1000000000000000));
  });

  test(
    'fiat rejects invalid quotes without applying the bitcoin field cap',
    () {
      for (final rate in [0.0, -1.0, double.nan, double.infinity]) {
        expect(Sats.tryFromFiat('1', rate), isNull);
      }
      for (final text in ['', '1.', '-1', '1e3', '0,15', '1\n']) {
        expect(Sats.tryFromFiat(text, 80000), isNull, reason: text);
      }
      expect(Sats.tryFromFiat('21000000', 1)?.value, Sats.maxBitcoinSupply);
      expect(
        Sats.tryFromFiat('21000001', 1)?.value,
        BigInt.parse('2100000100000000'),
      );
      expect(
        Sats.tryFromFiat('1${'0' * 400}', 1)?.value,
        BigInt.from(10).pow(408),
      );
    },
  );
}
