// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2626
// Finding: a fiat amount with a missing (zero) exchange rate crashes conversion.
// Regression test for the fix.

import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2626 missing exchange rate', () {
    test('fiat conversion with a zero rate returns zero', () {
      expect(ConvertAmount.fiatToBtc(10, 0), 0);
      expect(ConvertAmount.fiatToSats(10, 0), 0);
    });

    test('non-positive rates are unavailable', () {
      expect(ConvertAmount.fiatToBtc(10, -1), 0);
    });
  });
}
