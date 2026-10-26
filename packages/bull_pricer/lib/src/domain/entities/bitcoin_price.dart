import 'package:bull_pricer/src/domain/entities/supported_currency.dart';

/// The price of one bitcoin in [currency], as the price service gave it at
/// [fetchedAt]. A cached price keeps the time it was fetched, not the time it
/// was read.
final class BitcoinPrice {
  final SupportedCurrency currency;
  final double fiatAmount;
  final DateTime fetchedAt;

  BitcoinPrice({
    required this.currency,
    required this.fiatAmount,
    required this.fetchedAt,
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
      other is BitcoinPrice &&
      currency == other.currency &&
      fiatAmount == other.fiatAmount &&
      fetchedAt == other.fetchedAt;

  @override
  int get hashCode => Object.hash(currency, fiatAmount, fetchedAt);

  @override
  String toString() =>
      '$fiatAmount ${currency.code}/BTC at ${fetchedAt.toIso8601String()}';
}
