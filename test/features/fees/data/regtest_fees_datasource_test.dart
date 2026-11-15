import 'package:bb_mobile/features/fees/data/regtest_fees_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Electrum BTC per kB converts to sat per vbyte', () {
    expect(RegtestFeesDatasource.fromEstimate(0.00001).satPerKwu, 250);
  });
  test('unavailable and malformed estimates never become a fee preset', () {
    for (final estimate in [
      -1.0,
      0.0,
      double.nan,
      double.infinity,
      0.000000000001,
    ]) {
      expect(
        () => RegtestFeesDatasource.fromEstimate(estimate),
        throwsFormatException,
      );
    }
  });
}
