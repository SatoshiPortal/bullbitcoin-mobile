import 'package:bull_pricer/src/domain/entities/supported_currency.dart';

final class PricePoint {
  final SupportedCurrency currency;
  final double fiatAmount;
  final DateTime time;

  PricePoint({
    required this.currency,
    required this.fiatAmount,
    required this.time,
  }) {
    if (!fiatAmount.isFinite || fiatAmount <= 0) {
      throw ArgumentError.value(
        fiatAmount,
        'fiatAmount',
        'must be finite and greater than zero',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PricePoint &&
      currency == other.currency &&
      fiatAmount == other.fiatAmount &&
      time == other.time;

  @override
  int get hashCode => Object.hash(currency, fiatAmount, time);

  @override
  String toString() =>
      '$fiatAmount ${currency.code}/BTC at ${time.toIso8601String()}';
}
