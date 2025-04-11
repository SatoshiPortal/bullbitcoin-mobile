import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmountConversion', () {
    final amountConversion = AmountConversion();

    test('satsToBtc', () {
      expect(amountConversion.satsToBtc(100000000), 1.0);
      expect(amountConversion.satsToBtc(50000000), 0.5);
      expect(amountConversion.satsToBtc(10000000), 0.1);
      expect(amountConversion.satsToBtc(1000000), 0.01);
      expect(amountConversion.satsToBtc(100000), 0.001);
      expect(amountConversion.satsToBtc(10000), 0.0001);
      expect(amountConversion.satsToBtc(1000), 0.00001);
      expect(amountConversion.satsToBtc(100), 0.000001);
      expect(amountConversion.satsToBtc(10), 0.0000001);
      expect(amountConversion.satsToBtc(1), 0.00000001);
    });

    test('btcToSats', () {
      expect(amountConversion.btcToSats(1.0), 100000000);
      expect(amountConversion.btcToSats(0.5), 50000000);
      expect(amountConversion.btcToSats(0.1), 10000000);
      expect(amountConversion.btcToSats(0.01), 1000000);
      expect(amountConversion.btcToSats(0.001), 100000);
      expect(amountConversion.btcToSats(0.0001), 10000);
      expect(amountConversion.btcToSats(0.00001), 1000);
      expect(amountConversion.btcToSats(0.000001), 100);
      expect(amountConversion.btcToSats(0.0000001), 10);
      expect(amountConversion.btcToSats(0.00000001), 1);
    });

    test('btcToFiat', () {
      expect(amountConversion.btcToFiat(1.0, 50000), 50000.00);
      expect(amountConversion.btcToFiat(0.5, 50000), 25000.00);
      expect(amountConversion.btcToFiat(0.1, 50000), 5000.00);
      expect(amountConversion.btcToFiat(0.01, 50000), 500.00);
    });

    test('fiatToBtc', () {
      expect(amountConversion.fiatToBtc(50000, 50000), 1.0);
      expect(amountConversion.fiatToBtc(25000, 50000), 0.5);
      expect(amountConversion.fiatToBtc(5000, 50000), 0.1);
      expect(amountConversion.fiatToBtc(500, 50000), 0.01);
    });

    test('satsToFiat', () {
      expect(amountConversion.satsToFiat(100000000, 50000), 50000.00);
      expect(amountConversion.satsToFiat(50000000, 50000), 25000.00);
      expect(amountConversion.satsToFiat(10000000, 50000), 5000.00);
      expect(amountConversion.satsToFiat(1000000, 50000), 500.00);
    });

    test('fiatToSats', () {
      expect(amountConversion.fiatToSats(50000, 50000), 100000000);
      expect(amountConversion.fiatToSats(25000, 50000), 50000000);
      expect(amountConversion.fiatToSats(5000, 50000), 10000000);
      expect(amountConversion.fiatToSats(500, 50000), 1000000);
    });
  });

  group('AmountFormatting', () {
    test('formatSats', () {
      expect(AmountFormatting.formatSats(1000), '1,000 sats');
      expect(AmountFormatting.formatSats(1000000), '1,000,000 sats');
      expect(AmountFormatting.formatSats(1234567), '1,234,567 sats');
    });

    test('formatBtc', () {
      expect(AmountFormatting.formatBtc(1.0), '1 BTC');
      expect(AmountFormatting.formatBtc(0.5), '0.5 BTC');
      expect(AmountFormatting.formatBtc(0.09), '0.09000000 BTC');
      expect(AmountFormatting.formatBtc(0.00000001), '0.00000001 BTC');
      expect(AmountFormatting.formatBtc(1.23456789), '1.23456789 BTC');
    });

    test('formatFiat', () {
      expect(AmountFormatting.formatFiat(1000, 'USD'), '1,000.00 USD');
      expect(AmountFormatting.formatFiat(1000.50, 'USD'), '1,000.50 USD');
      expect(AmountFormatting.formatFiat(1234.56, 'EUR'), '1,234.56 EUR');
    });
  });
}
