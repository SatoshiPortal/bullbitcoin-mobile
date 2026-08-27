import 'package:bb_mobile/core/fees/data/mappers/mempool_fees_mapper.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2618
// Finding: fee-oracle values are accepted without bounds or ordering checks.
// Regression test for the fix.
void main() {
  group('Security audit #2618 unbounded fee oracle', () {
    test('clamps hostile values and enforces monotonic tiers', () {
      final model = MempoolFeesModel.fromJson({
        'fastestFee': 0,
        'halfHourFee': -1,
        'hourFee': -2,
        'economyFee': 999999999999999999,
        'minimumFee': -50,
      });

      final options = MempoolFeesMapper.toFeeOptions(model);
      expect((options.slow as RelativeFee).satPerVbyte, 1000);
      expect(
        (options.fastest as RelativeFee).satPerVbyte,
        greaterThanOrEqualTo((options.economic as RelativeFee).satPerVbyte),
      );
      expect((options.economic as RelativeFee).satPerVbyte, 1000);
    });

    test('clamps zero and negative fee fields at the mapper boundary', () {
      final model = MempoolFeesModel.fromJson({
        'fastestFee': -100,
        'halfHourFee': 0,
        'hourFee': -1,
        'economyFee': 0,
        'minimumFee': -50,
      });
      final options = MempoolFeesMapper.toFeeOptions(model);
      expect((options.fastest as RelativeFee).satPerVbyte, 0.1);
      expect(options.minRelay.satPerVbyte, 0.1);
    });
  });
}
