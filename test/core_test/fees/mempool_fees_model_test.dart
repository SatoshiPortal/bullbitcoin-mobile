import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MempoolFeesModel.fromJson', () {
    test('parses decimal (precise) fields', () {
      final m = MempoolFeesModel.fromJson({
        'fastestFee': 1.203,
        'halfHourFee': 0.92,
        'hourFee': 0.65,
        'economyFee': 0.2,
        'minimumFee': 0.1,
      });
      expect(m.fastestFee, 1.203);
      expect(m.halfHourFee, 0.92);
      expect(m.hourFee, 0.65);
      expect(m.economyFee, 0.2);
      expect(m.minimumFee, 0.1);
    });

    test('parses whole numbers encoded as JSON ints without throwing', () {
      // The recommended fallback (and quiet blocks) return integers; a bare
      // `as double` cast would throw on these.
      final m = MempoolFeesModel.fromJson({
        'fastestFee': 3,
        'halfHourFee': 3,
        'hourFee': 1,
        'economyFee': 1,
        'minimumFee': 1,
      });
      expect(m.fastestFee, 3.0);
      expect(m.hourFee, 1.0);
      expect(m.economyFee, 1.0);
    });

    test('parses a payload mixing int and double (real testnet shape)', () {
      final m = MempoolFeesModel.fromJson({
        'fastestFee': 1,
        'halfHourFee': 0.5,
        'hourFee': 0.1,
        'economyFee': 0.1,
        'minimumFee': 0.1,
      });
      expect(m.fastestFee, 1.0);
      expect(m.halfHourFee, 0.5);
      expect(m.hourFee, 0.1);
    });
  });
}
