import 'package:bb_mobile/core/fees/data/mappers/mempool_fees_mapper.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the tier policy after the precise-endpoint migration:
///   Fastest  <- fastestFee
///   Economic <- hourFee
///   Slow     <- economyFee, floored at the network minrelayfee.
/// halfHourFee and minimumFee never reach the UI tiers.
MempoolFeesModel _model({
  double fastestFee = 2,
  double halfHourFee = 1.5,
  double hourFee = 1,
  double economyFee = 0.5,
  double minimumFee = 0.1,
}) => MempoolFeesModel(
  fastestFee: fastestFee,
  halfHourFee: halfHourFee,
  hourFee: hourFee,
  economyFee: economyFee,
  minimumFee: minimumFee,
);

void main() {
  group('MempoolFeesMapper.toFeeOptions', () {
    test('Fastest <- fastestFee, Economic <- hourFee, Slow <- economyFee', () {
      final opts = MempoolFeesMapper.toFeeOptions(
        _model(fastestFee: 2, hourFee: 1, economyFee: 0.5),
      );
      expect((opts.fastest as RelativeFee).satPerVbyte, 2);
      expect((opts.economic as RelativeFee).satPerVbyte, 1);
      expect((opts.slow as RelativeFee).satPerVbyte, 0.5);
    });

    test('Slow passes economyFee through verbatim when above the floor', () {
      final opts = MempoolFeesMapper.toFeeOptions(_model(economyFee: 0.2));
      expect((opts.slow as RelativeFee).satPerVbyte, 0.2);
    });

    test('Slow is floored at the network minrelayfee', () {
      // economyFee below the 0.1 floor is clamped up so the preset stays
      // relayable.
      final opts = MempoolFeesMapper.toFeeOptions(_model(economyFee: 0.05));
      expect(
        (opts.slow as RelativeFee).satPerVbyte,
        NetworkFeeRelayPolicy.minRelaySatPerVbyte,
      );
    });

    test('every tier is floored, preserving Fastest >= Economic >= Slow', () {
      // All fields below the floor: flooring all three keeps them ordered
      // (and relayable) instead of inverting Slow above Economic.
      final opts = MempoolFeesMapper.toFeeOptions(
        _model(fastestFee: 0.08, hourFee: 0.05, economyFee: 0.02),
      );
      final fastest = (opts.fastest as RelativeFee).satPerVbyte;
      final economic = (opts.economic as RelativeFee).satPerVbyte;
      final slow = (opts.slow as RelativeFee).satPerVbyte;
      expect(slow, NetworkFeeRelayPolicy.minRelaySatPerVbyte);
      expect(economic, greaterThanOrEqualTo(slow));
      expect(fastest, greaterThanOrEqualTo(economic));
    });

    test('halfHourFee and minimumFee do not affect any tier', () {
      final opts = MempoolFeesMapper.toFeeOptions(
        _model(
          fastestFee: 3,
          halfHourFee: 99,
          hourFee: 1.2,
          economyFee: 0.3,
          minimumFee: 99,
        ),
      );
      expect((opts.fastest as RelativeFee).satPerVbyte, 3);
      expect((opts.economic as RelativeFee).satPerVbyte, 1.2);
      expect((opts.slow as RelativeFee).satPerVbyte, 0.3);
    });
  });
}
