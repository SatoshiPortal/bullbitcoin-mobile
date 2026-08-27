// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2607
// Finding: an out-of-range BBQR part index is accepted and permanently prevents completion.
// Regression test for the fix.

import 'package:bb_mobile/core/bbqr/bbqr_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2607 BBQR frame validation', () {
    test('rejects an out-of-range share', () {
      expect(BbqrOptions.isValid('B\$HX0235'), isFalse);
      expect(() => BbqrOptions.decode('B\$HX0235'), throwsA(anything));
    });

    test('rejects a zero total', () {
      expect(BbqrOptions.isValid('B\$HX0000'), isFalse);
      expect(() => BbqrOptions.decode('B\$HX0000'), throwsA(anything));
    });
  });
}
