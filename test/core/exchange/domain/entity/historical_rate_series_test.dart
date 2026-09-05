import 'package:bb_mobile/core/exchange/domain/entity/historical_rate_series.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:flutter_test/flutter_test.dart';

Rate _rate(String iso, double price, RateTimelineInterval interval) => Rate(
  fromCurrency: 'BTC',
  toCurrency: 'USD',
  interval: interval,
  createdAt: DateTime.parse(iso),
  indexPrice: price,
);

DateTime _at(String iso) => DateTime.parse(iso);

void main() {
  group('HistoricalRateSeries', () {
    test('an empty series resolves nothing', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: const [],
      );
      expect(series.priceAt(_at('2026-09-01T12:00:00Z')), isNull);
      expect(series.isEmpty, isTrue);
    });

    test('an exact fifteen bucket returns its price', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [
          _rate('2026-09-01T12:00:00Z', 100000, RateTimelineInterval.fifteen),
          _rate('2026-09-01T12:15:00Z', 101000, RateTimelineInterval.fifteen),
        ],
      );
      expect(series.priceAt(_at('2026-09-01T12:15:00Z')), 101000);
    });

    test('an anchor between buckets takes the nearer one', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [
          _rate('2026-09-01T12:00:00Z', 100000, RateTimelineInterval.fifteen),
          _rate('2026-09-01T12:15:00Z', 101000, RateTimelineInterval.fifteen),
        ],
      );
      // 12:04 is nearer 12:00; 12:11 is nearer 12:15.
      expect(series.priceAt(_at('2026-09-01T12:04:00Z')), 100000);
      expect(series.priceAt(_at('2026-09-01T12:11:00Z')), 101000);
    });

    test('the fifteen tier is preferred over the day tier', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [
          _rate('2026-09-01T12:00:00Z', 100000, RateTimelineInterval.fifteen),
          _rate('2026-09-01T00:00:00Z', 90000, RateTimelineInterval.day),
        ],
      );
      expect(series.priceAt(_at('2026-09-01T12:05:00Z')), 100000);
    });

    test('falls back to the day tier beyond fifteen coverage', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [
          _rate('2026-09-01T12:00:00Z', 100000, RateTimelineInterval.fifteen),
          _rate('2024-03-04T00:00:00Z', 55000, RateTimelineInterval.day),
        ],
      );
      expect(series.priceAt(_at('2024-03-04T09:30:00Z')), 55000);
    });

    test('refuses a fifteen bucket more than 15 minutes away', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [
          _rate('2026-09-01T12:00:00Z', 100000, RateTimelineInterval.fifteen),
        ],
      );
      expect(series.priceAt(_at('2026-09-01T12:14:00Z')), 100000);
      expect(series.priceAt(_at('2026-09-01T12:16:00Z')), isNull);
    });

    test('refuses a day row more than a day away', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [_rate('2024-03-04T00:00:00Z', 55000, RateTimelineInterval.day)],
      );
      expect(series.priceAt(_at('2024-03-04T23:00:00Z')), 55000);
      expect(series.priceAt(_at('2024-03-05T06:00:00Z')), isNull);
    });

    test('never interpolates across a gap', () {
      // The API has real gaps of 12 to 17 consecutive days. A value invented
      // across one would be fabrication presented as a rate.
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [
          _rate('2024-08-10T00:00:00Z', 50000, RateTimelineInterval.day),
          _rate('2024-08-27T00:00:00Z', 62000, RateTimelineInterval.day),
        ],
      );
      expect(series.priceAt(_at('2024-08-18T00:00:00Z')), isNull);
      // The edges of the gap still resolve within tolerance.
      expect(series.priceAt(_at('2024-08-10T12:00:00Z')), 50000);
      expect(series.priceAt(_at('2024-08-26T18:00:00Z')), 62000);
    });

    test('an anchor before the first row resolves nothing', () {
      // Nothing exists before 2023-03-15, so a 2021 transaction has no rate.
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [_rate('2023-03-15T00:00:00Z', 24000, RateTimelineInterval.day)],
      );
      expect(series.priceAt(_at('2021-11-14T00:00:00Z')), isNull);
    });

    test('rows arriving out of order are still resolved correctly', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [
          _rate('2026-09-03T00:00:00Z', 103000, RateTimelineInterval.day),
          _rate('2026-09-01T00:00:00Z', 101000, RateTimelineInterval.day),
          _rate('2026-09-02T00:00:00Z', 102000, RateTimelineInterval.day),
        ],
      );
      expect(series.priceAt(_at('2026-09-02T01:00:00Z')), 102000);
    });

    test('a row without an index price is ignored', () {
      final series = HistoricalRateSeries.from(
        currency: 'USD',
        rates: [
          Rate(
            fromCurrency: 'BTC',
            toCurrency: 'USD',
            interval: RateTimelineInterval.day,
            createdAt: DateTime.parse('2026-09-01T00:00:00Z'),
          ),
        ],
      );
      expect(series.priceAt(_at('2026-09-01T00:00:00Z')), isNull);
      expect(series.isEmpty, isTrue);
    });

    test('resolves against a large series without walking it', () {
      // ~9,863 rows per currency is the real size. Binary search keeps this
      // off the scroll path; a linear scan per row would not.
      final rates = <Rate>[];
      var t = DateTime.parse('2023-03-15T00:00:00Z');
      for (var i = 0; i < 1223; i++) {
        rates.add(
          _rate(
            t.toIso8601String(),
            20000 + i.toDouble(),
            RateTimelineInterval.day,
          ),
        );
        t = t.add(const Duration(days: 1));
      }
      final series = HistoricalRateSeries.from(currency: 'USD', rates: rates);
      expect(series.priceAt(_at('2023-03-15T00:00:00Z')), 20000);
      expect(series.priceAt(_at('2024-07-01T00:00:00Z')), 20474);
      expect(series.priceAt(rates.last.createdAt), 20000 + 1222);
    });
  });
}
