import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rate_history.freezed.dart';

enum RateTimelineInterval {
  fifteen('fifteen'),
  hour('hour'),
  day('day'),
  week('week');

  const RateTimelineInterval(this.value);
  final String value;

  static RateTimelineInterval fromString(String value) {
    switch (value) {
      case 'fifteen':
        return RateTimelineInterval.fifteen;
      case 'hour':
        return RateTimelineInterval.hour;
      case 'day':
        return RateTimelineInterval.day;
      case 'week':
        return RateTimelineInterval.week;
      default:
        throw Exception('Unknown RateTimelineInterval: $value');
    }
  }
}

@freezed
sealed class Rate with _$Rate {
  const factory Rate({
    FiatCurrency? fromCurrency,
    @Default('BTC') String? toCurrency,
    double? marketPrice,
    double? price,
    String? priceCurrency,
    int? precision,
    double? indexPrice,
    double? userPrice,
    DateTime? createdAt,
  }) = _Rate;
}

@freezed
sealed class RateHistory with _$RateHistory {
  const factory RateHistory({
    FiatCurrency? fromCurrency,
    @Default('BTC') String? toCurrency,
    int? precision,
    RateTimelineInterval? interval,
    List<Rate>? rates,
  }) = _RateHistory;
}
