import 'package:bb_mobile/core_deprecated/utils/amount_conversions.dart';
import 'package:bb_mobile/core_deprecated/utils/amount_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmountConversion', () {
    test('satsToBtc', () {
      expect(ConvertAmount.satsToBtc(100000000), 1.0);
      expect(ConvertAmount.satsToBtc(50000000), 0.5);
      expect(ConvertAmount.satsToBtc(10000000), 0.1);
      expect(ConvertAmount.satsToBtc(1000000), 0.01);
      expect(ConvertAmount.satsToBtc(100000), 0.001);
      expect(ConvertAmount.satsToBtc(10000), 0.0001);
      expect(ConvertAmount.satsToBtc(1000), 0.00001);
      expect(ConvertAmount.satsToBtc(100), 0.000001);
      expect(ConvertAmount.satsToBtc(10), 0.0000001);
      expect(ConvertAmount.satsToBtc(1), 0.00000001);
    });

    test('btcToSats', () {
      expect(ConvertAmount.btcToSats(1.0), 100000000);
      expect(ConvertAmount.btcToSats(0.5), 50000000);
      expect(ConvertAmount.btcToSats(0.1), 10000000);
      expect(ConvertAmount.btcToSats(0.01), 1000000);
      expect(ConvertAmount.btcToSats(0.001), 100000);
      expect(ConvertAmount.btcToSats(0.0001), 10000);
      expect(ConvertAmount.btcToSats(0.00001), 1000);
      expect(ConvertAmount.btcToSats(0.000001), 100);
      expect(ConvertAmount.btcToSats(0.0000001), 10);
      expect(ConvertAmount.btcToSats(0.00000001), 1);
    });

    test('btcToFiat', () {
      expect(ConvertAmount.btcToFiat(1.0, 50000), 50000.00);
      expect(ConvertAmount.btcToFiat(0.5, 50000), 25000.00);
      expect(ConvertAmount.btcToFiat(0.1, 50000), 5000.00);
      expect(ConvertAmount.btcToFiat(0.01, 50000), 500.00);
    });

    test('fiatToBtc', () {
      expect(ConvertAmount.fiatToBtc(50000, 50000), 1.0);
      expect(ConvertAmount.fiatToBtc(25000, 50000), 0.5);
      expect(ConvertAmount.fiatToBtc(5000, 50000), 0.1);
      expect(ConvertAmount.fiatToBtc(500, 50000), 0.01);
    });

    test('satsToFiat', () {
      expect(ConvertAmount.satsToFiat(100000000, 50000), 50000.00);
      expect(ConvertAmount.satsToFiat(50000000, 50000), 25000.00);
      expect(ConvertAmount.satsToFiat(10000000, 50000), 5000.00);
      expect(ConvertAmount.satsToFiat(1000000, 50000), 500.00);
    });

    test('fiatToSats', () {
      expect(ConvertAmount.fiatToSats(50000, 50000), 100000000);
      expect(ConvertAmount.fiatToSats(25000, 50000), 50000000);
      expect(ConvertAmount.fiatToSats(5000, 50000), 10000000);
      expect(ConvertAmount.fiatToSats(500, 50000), 1000000);
    });
  });

  group('FormatAmount', () {
    test('formatSats', () {
      expect(FormatAmount.sats(1000), '1,000 sats');
      expect(FormatAmount.sats(1000000), '1,000,000 sats');
      expect(FormatAmount.sats(1234567), '1,234,567 sats');
    });

    test('formatBtc', () {
      expect(FormatAmount.btc(1.0), '1 BTC');
      expect(FormatAmount.btc(0.5), '0.5 BTC');
      expect(FormatAmount.btc(0.09), '0.09000000 BTC');
      expect(FormatAmount.btc(0.00000001), '0.00000001 BTC');
      expect(FormatAmount.btc(1.23456789), '1.23456789 BTC');
      expect(FormatAmount.btc(0.1), '0.1 BTC');
      expect(FormatAmount.btc(0.0000001), '0.00000010 BTC');
      expect(FormatAmount.btc(0.09), '0.09000000 BTC');
      expect(FormatAmount.btc(0.0), '0 BTC');
      expect(FormatAmount.btc(1.234), '1.234 BTC');
      expect(FormatAmount.btc(25.12345), '25.12345 BTC');
    });

    test('formatFiat', () {
      expect(FormatAmount.fiat(1000, 'USD'), '1,000.00 USD');
      expect(FormatAmount.fiat(1000.50, 'USD'), '1,000.50 USD');
      expect(FormatAmount.fiat(1234.56, 'EUR'), '1,234.56 EUR');
    });
  });
}
