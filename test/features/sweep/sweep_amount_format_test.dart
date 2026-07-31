import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sweep/ui/sweep_amount_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sweep amount input', () {
    test('round-trips satoshis through exact BTC text', () {
      final amounts = [
        BigInt.one,
        BigInt.from(12345678),
        BigInt.from(100000000),
      ];

      for (final amount in amounts) {
        final text = formatSweepAmountInput(amount, BitcoinUnit.btc);
        expect(parseSweepAmountInput(text, BitcoinUnit.btc), amount);
      }
    });

    test('accepts the locale decimal comma', () {
      expect(parseSweepAmountInput('0,00000001', BitcoinUnit.btc), BigInt.one);
    });

    test('rejects sub-satoshi precision and decimal sats', () {
      expect(parseSweepAmountInput('0.000000001', BitcoinUnit.btc), isNull);
      expect(parseSweepAmountInput('1.5', BitcoinUnit.sats), isNull);
    });
  });

  test('hidden amounts preserve the selected denomination', () {
    expect(
      formatSweepAmount(BigInt.from(1000), BitcoinUnit.btc, hidden: true),
      '•••• BTC',
    );
    expect(
      formatSweepAmount(BigInt.from(1000), BitcoinUnit.sats, hidden: true),
      '•••• sats',
    );
  });
}
