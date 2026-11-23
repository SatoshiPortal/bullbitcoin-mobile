import 'package:swap_feature/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  final at = DateTime.utc(2026, 11, 19, 14, 32);

  test(
    'captures the exact fiat intent and quote independently of later prices',
    () {
      final snapshot = SwapAmountConversion.fromEdit(
        sats: BigInt.from(25000),
        currencyCode: 'CAD',
        text: '31.25',
        rate: 125000,
        quotedAt: at,
      );
      expect(snapshot?.sats, Sats.fromInt(25000));
      expect(snapshot?.enteredText, '31.25');
      expect(snapshot?.currencyCode, 'CAD');
      expect(snapshot?.rate, 125000);
      expect(snapshot?.quotedAt, at);
      final repriced = SwapAmountConversion.fromEdit(
        sats: BigInt.from(31250),
        currencyCode: 'CAD',
        text: '31.25',
        rate: 100000,
        quotedAt: at.add(const Duration(minutes: 1)),
      );
      expect(repriced?.sats, Sats.fromInt(31250));
      expect(snapshot?.sats, Sats.fromInt(25000));
    },
  );

  test('cannot capture an unavailable or mismatched conversion', () {
    for (final rate in [
      null,
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      100000.0,
    ]) {
      expect(
        SwapAmountConversion.fromEdit(
          sats: BigInt.from(25000),
          currencyCode: 'CAD',
          text: '31.25',
          rate: rate,
          quotedAt: at,
        ),
        isNull,
      );
    }
    expect(
      SwapAmountConversion.fromEdit(
        sats: BigInt.from(25000),
        currencyCode: 'CAD',
        text: '31.25',
        rate: 125000,
        quotedAt: null,
      ),
      isNull,
    );
  });
}
