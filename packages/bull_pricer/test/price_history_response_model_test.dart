import 'package:bull_pricer/src/data/models/price_history_response_model.dart';
import 'package:test/test.dart';

void main() {
  group('PriceHistoryResponseModel.fromJson', () {
    test('reads a getIndexRateHistory answer', () {
      // Real `element` from mainnet `getIndexRateHistory`, BTC → CAD, day.
      final response = PriceHistoryResponseModel.fromJson({
        'interval': 'day',
        'precision': 2,
        'fromCurrency': 'BTC',
        'toCurrency': 'CAD',
        'rates': [
          {
            'periodStart': '2026-11-01T00:00:00.000Z',
            'createdAt': '2026-11-01T15:30:27.921Z',
            'indexPrice': 10894585,
          },
          {
            'periodStart': '2026-11-02T00:00:00.000Z',
            'createdAt': '2026-11-02T00:00:28.769Z',
            'indexPrice': 10936730,
          },
        ],
      });

      expect(response.points, [
        (time: DateTime.utc(2026, 11, 1), fiatAmount: 108945.85),
        (time: DateTime.utc(2026, 11, 2), fiatAmount: 109367.30),
      ]);
    });

    test('dates a point by createdAt when it has no periodStart', () {
      final response = PriceHistoryResponseModel.fromJson({
        'rates': [
          {'createdAt': '2026-11-01T15:30:27.921Z', 'indexPrice': 10894585},
        ],
      });

      expect(
        response.points.single.time,
        DateTime.utc(2026, 11, 1, 15, 30, 27, 921),
      );
    });

    test('returns the points oldest first', () {
      final response = PriceHistoryResponseModel.fromJson({
        'rates': [
          {'periodStart': '2026-11-02T00:00:00.000Z', 'indexPrice': 2},
          {'periodStart': '2026-11-01T00:00:00.000Z', 'indexPrice': 1},
        ],
      });

      expect(response.points.map((p) => p.time.day), [1, 2]);
    });

    test('skips a point without a usable time or price', () {
      final response = PriceHistoryResponseModel.fromJson({
        'precision': 2,
        'rates': [
          {'indexPrice': 10894585},
          {'periodStart': 'yesterday', 'indexPrice': 10894585},
          {'periodStart': '2026-11-01T00:00:00.000Z', 'indexPrice': '10894585'},
          {'periodStart': '2026-11-01T00:00:00.000Z', 'indexPrice': 0},
          {'periodStart': '2026-11-01T00:00:00.000Z', 'indexPrice': -5},
          'not a point',
          {'periodStart': '2026-11-02T00:00:00.000Z', 'indexPrice': 10936730},
        ],
      });

      expect(response.points.single.fiatAmount, 109367.30);
    });

    test('divides by a precision too large for an int', () {
      final response = PriceHistoryResponseModel.fromJson({
        'precision': 20,
        'rates': [
          {'periodStart': '2026-11-01T00:00:00.000Z', 'indexPrice': 10894585},
        ],
      });

      expect(
        response.points.single.fiatAmount,
        closeTo(10894585 / 1e20, 1e-30),
      );
    });

    test('skips a point unusable after its precision', () {
      final response = PriceHistoryResponseModel.fromJson({
        'precision': 400,
        'rates': [
          {'periodStart': '2026-11-01T00:00:00.000Z', 'indexPrice': 10894585},
        ],
      });

      expect(response.points, isEmpty);
    });

    test(
      'rejects an answer without a list of points or a usable precision',
      () {
        for (final answer in <Map<String, dynamic>>[
          {},
          {'rates': 'none'},
          {'rates': <Object>[], 'precision': '2'},
        ]) {
          expect(
            () => PriceHistoryResponseModel.fromJson(answer),
            throwsFormatException,
            reason: '$answer',
          );
        }
      },
    );
  });
}
