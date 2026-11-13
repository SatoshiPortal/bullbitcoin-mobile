import 'dart:math' show pow;

final class PriceHistoryResponseModel {
  final List<({DateTime time, double fiatAmount})> points;

  const PriceHistoryResponseModel(this.points);

  factory PriceHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    final rates = json['rates'];
    final precision = json['precision'] ?? 2;
    if (rates is! List || precision is! int) {
      throw FormatException('Price history answer has no usable rates', json);
    }
    final divisor = pow(10.0, precision);
    final points = <({DateTime time, double fiatAmount})>[];
    for (final rate in rates) {
      if (rate is! Map) continue;
      final time = DateTime.tryParse(
        '${rate['periodStart'] ?? rate['createdAt']}',
      );
      final indexPrice = rate['indexPrice'];
      if (time == null || indexPrice is! num) continue;
      final fiatAmount = indexPrice / divisor;
      if (!fiatAmount.isFinite || fiatAmount <= 0) continue;
      points.add((time: time.toUtc(), fiatAmount: fiatAmount));
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return PriceHistoryResponseModel(points);
  }
}
