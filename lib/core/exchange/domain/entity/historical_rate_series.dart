import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';

/// The BTC-to-fiat rates for one currency, held in memory and resolved by
/// binary search.
///
/// The transaction history prices every visible row against the moment that
/// transaction happened, so a lookup sits directly on the scroll path. The
/// whole cache is about 9,863 rows per currency — near 1 MB — so it is held
/// as two sorted arrays and searched, rather than queried per row.
///
/// Two tiers, because the rate history is only fine-grained near the present:
/// [RateTimelineInterval.fifteen] covers the recent window, and
/// [RateTimelineInterval.day] covers everything back to the start of the
/// available history. The finer tier wins wherever it reaches.
class HistoricalRateSeries {
  /// How far an anchor may sit from a `fifteen` row and still use it.
  static const fifteenTolerance = Duration(minutes: 15);

  /// How far an anchor may sit from a `day` row and still use it.
  static const dayTolerance = Duration(days: 1);

  final String currency;
  final List<int> _fifteenMillis;
  final List<double> _fifteenPrices;
  final List<int> _dayMillis;
  final List<double> _dayPrices;

  const HistoricalRateSeries._({
    required this.currency,
    required this._fifteenMillis,
    required this._fifteenPrices,
    required this._dayMillis,
    required this._dayPrices,
  });

  /// Builds a series from cached rates.
  ///
  /// Rows without an `indexPrice` are dropped: `indexPrice` is the only price
  /// field the rate history populates, so a row without one carries no rate.
  /// Input order does not matter; each tier is sorted here.
  factory HistoricalRateSeries.from({
    required String currency,
    required List<Rate> rates,
  }) {
    final fifteen = <MapEntry<int, double>>[];
    final day = <MapEntry<int, double>>[];

    for (final rate in rates) {
      final price = rate.indexPrice;
      if (price == null) continue;
      final entry = MapEntry(
        rate.createdAt.toUtc().millisecondsSinceEpoch,
        price,
      );
      switch (rate.interval) {
        case RateTimelineInterval.fifteen:
          fifteen.add(entry);
        case RateTimelineInterval.day:
        case RateTimelineInterval.hour:
        case RateTimelineInterval.week:
          // `hour` and `week` are not backfilled, but a stray row must not be
          // dropped silently — the coarse tier can still use it.
          day.add(entry);
      }
    }

    fifteen.sort((a, b) => a.key.compareTo(b.key));
    day.sort((a, b) => a.key.compareTo(b.key));

    return HistoricalRateSeries._(
      currency: currency,
      fifteenMillis: fifteen.map((e) => e.key).toList(growable: false),
      fifteenPrices: fifteen.map((e) => e.value).toList(growable: false),
      dayMillis: day.map((e) => e.key).toList(growable: false),
      dayPrices: day.map((e) => e.value).toList(growable: false),
    );
  }

  bool get isEmpty => _fifteenMillis.isEmpty && _dayMillis.isEmpty;

  /// The rate at [anchor], or null when no row sits close enough.
  ///
  /// Returning null is a real answer, not a failure: nothing exists before
  /// 2023-03-15, and the history has gaps of up to 17 consecutive days. This
  /// **never interpolates** — a value invented across a gap would be
  /// fabrication presented as a rate.
  double? priceAt(DateTime anchor) {
    final target = anchor.toUtc().millisecondsSinceEpoch;
    return _nearest(
          _fifteenMillis,
          _fifteenPrices,
          target,
          fifteenTolerance.inMilliseconds,
        ) ??
        _nearest(_dayMillis, _dayPrices, target, dayTolerance.inMilliseconds);
  }

  /// The nearest price within [toleranceMillis], or null.
  static double? _nearest(
    List<int> millis,
    List<double> prices,
    int target,
    int toleranceMillis,
  ) {
    if (millis.isEmpty) return null;

    // Lower bound: the first index whose timestamp is >= target.
    var lo = 0;
    var hi = millis.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (millis[mid] < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    // The nearest row is on one side or the other of that boundary.
    var bestIndex = -1;
    var bestDistance = -1;
    for (final candidate in [lo - 1, lo]) {
      if (candidate < 0 || candidate >= millis.length) continue;
      final distance = (millis[candidate] - target).abs();
      if (bestIndex == -1 || distance < bestDistance) {
        bestIndex = candidate;
        bestDistance = distance;
      }
    }

    if (bestIndex == -1 || bestDistance > toleranceMillis) return null;
    return prices[bestIndex];
  }
}
