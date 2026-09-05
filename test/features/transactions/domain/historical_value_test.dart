import 'package:bb_mobile/core/exchange/domain/entity/historical_rate_series.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction_anchor.dart';
import 'package:bb_mobile/features/transactions/presentation/historical_value.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(String iso) => DateTime.parse(iso);

HistoricalRateSeries _series(Map<String, double> points) =>
    HistoricalRateSeries.from(
      currency: 'USD',
      rates: points.entries
          .map(
            (e) => Rate(
              fromCurrency: 'BTC',
              toCurrency: 'USD',
              interval: RateTimelineInterval.fifteen,
              createdAt: DateTime.parse(e.key),
              indexPrice: e.value,
            ),
          )
          .toList(),
    );

void main() {
  // 1,000,000 sats = 0.01 BTC, so a rate of 100,000 gives 1,000 fiat.
  const oneMillionSats = 1000000;

  test('no anchor gives no value', () {
    expect(
      HistoricalValue.resolve(
        anchor: const NoAnchor(),
        series: _series({'2026-09-01T12:00:00Z': 100000}),
        amountSat: oneMillionSats,
      ),
      isNull,
    );
  });

  test('a single anchor prices the amount at that moment', () {
    final value = HistoricalValue.resolve(
      anchor: SingleAnchor(
        at: _at('2026-09-01T12:00:00Z'),
        reason: AnchorReason.sent,
      ),
      series: _series({'2026-09-01T12:00:00Z': 100000}),
      amountSat: oneMillionSats,
    );
    expect(value, isA<SingleValue>());
    expect((value! as SingleValue).fiat, closeTo(1000, 0.001));
    expect((value as SingleValue).reason, AnchorReason.sent);
  });

  test('an unpriceable anchor gives no value', () {
    // Before the rate history begins, so nothing will ever price it.
    expect(
      HistoricalValue.resolve(
        anchor: SingleAnchor(
          at: _at('2021-11-14T00:00:00Z'),
          reason: AnchorReason.confirmed,
        ),
        series: _series({'2026-09-01T12:00:00Z': 100000}),
        amountSat: oneMillionSats,
      ),
      isNull,
    );
  });

  test('a range prices both ends and orders them low to high', () {
    final value = HistoricalValue.resolve(
      anchor: RangeAnchor(
        from: _at('2026-09-01T12:00:00Z'),
        to: _at('2026-09-01T12:30:00Z'),
      ),
      series: _series({
        '2026-09-01T12:00:00Z': 101000,
        '2026-09-01T12:30:00Z': 100000,
      }),
      amountSat: oneMillionSats,
    );
    expect(value, isA<RangeValue>());
    final range = value! as RangeValue;
    // The price fell, so the later end is the low one.
    expect(range.low, closeTo(1000, 0.001));
    expect(range.high, closeTo(1010, 0.001));
  });

  test('a range whose start cannot be priced degrades to a single value', () {
    final value = HistoricalValue.resolve(
      anchor: RangeAnchor(
        from: _at('2021-11-14T00:00:00Z'),
        to: _at('2026-09-01T12:30:00Z'),
      ),
      series: _series({'2026-09-01T12:30:00Z': 100000}),
      amountSat: oneMillionSats,
    );
    expect(value, isA<SingleValue>());
    expect((value! as SingleValue).reason, AnchorReason.confirmed);
  });

  test('a range whose ends price identically degrades to a single value', () {
    // Showing one number twice as a range reads as a bug.
    final value = HistoricalValue.resolve(
      anchor: RangeAnchor(
        from: _at('2026-09-01T12:00:00Z'),
        to: _at('2026-09-01T12:10:00Z'),
      ),
      series: _series({'2026-09-01T12:00:00Z': 100000}),
      amountSat: oneMillionSats,
    );
    expect(value, isA<SingleValue>());
  });

  test('a range with no priceable end gives no value', () {
    expect(
      HistoricalValue.resolve(
        anchor: RangeAnchor(
          from: _at('2021-11-14T00:00:00Z'),
          to: _at('2021-11-14T00:30:00Z'),
        ),
        series: _series({'2026-09-01T12:00:00Z': 100000}),
        amountSat: oneMillionSats,
      ),
      isNull,
    );
  });
}
