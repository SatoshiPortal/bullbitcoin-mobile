import 'package:fees/src/domain/fees_entity.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts BTC/kvB to sat/vB and orders and caps all three tiers', () {
    final fees = mapElectrumFeeEstimates([0.00001, 0.00002, 0.5]);
    expect(fees.fastest.value, 1000);
    expect(fees.economic.value, 1000);
    expect(fees.slow.value, 1000);
    expect(fees.minRelay.value, 0.1);
    final precise = mapElectrumFeeEstimates([0.00001, 0.000005, 0.0000009]);
    expect(precise.fastest.value, 1);
    expect(precise.economic.value, 0.5);
    expect(precise.slow.value, 0.1);
  });

  test('rejects unavailable, non-finite and incomplete responses', () {
    for (final values in [
      [-1.0, 1.0, 1.0],
      [0.0, 1.0, 1.0],
      [0.000000000001, 1.0, 1.0],
      [double.nan, 1.0, 1.0],
      [1.0, double.infinity, 1.0],
      [1.0, 1.0],
    ]) {
      expect(() => mapElectrumFeeEstimates(values), throwsFormatException);
    }
  });
}
