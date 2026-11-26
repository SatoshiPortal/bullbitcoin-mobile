import 'package:meta/meta.dart';

/// The user's buy or sell limits, as `getBuyLimits` and `getSellLimits`
/// return them. Wire fields outside this owned contract are ignored.
@immutable
class OrderLimits {
  final num? minimum;
  final num? maximum;
  final List<OrderCurrencyLimits> currencyLimits;

  const OrderLimits({
    this.minimum,
    this.maximum,
    this.currencyLimits = const [],
  });
}

/// The limit values published for one currency.
@immutable
class OrderCurrencyLimits {
  final String currencyCode;
  final List<num> values;

  const OrderCurrencyLimits({required this.currencyCode, required this.values});
}
