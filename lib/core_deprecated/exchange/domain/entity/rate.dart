import 'package:freezed_annotation/freezed_annotation.dart';

part 'rate.freezed.dart';

enum RateTimelineInterval {
  fifteen('fifteen'),
  hour('hour'),
  day('day'),
  week('week');

  final String _interval;
  const RateTimelineInterval(this._interval);

  String get enumValue => _interval;
  String get value => _interval;

  static RateTimelineInterval fromValue(String value) {
    return RateTimelineInterval.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RateTimelineInterval.day,
    );
  }
}

@freezed
sealed class Rate with _$Rate {
  const factory Rate({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    required DateTime createdAt,
    double? marketPrice,
    double? price,
    String? priceCurrency,
    int? precision,
    double? indexPrice,
    double? userPrice,
  }) = _Rate;
  const Rate._();
}
