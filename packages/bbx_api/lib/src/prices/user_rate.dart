import 'package:meta/meta.dart';

/// The user's exchange rate as `public/price` returns it. Prices are integers
/// in units of 10^-[precision] of the quote currency.
@immutable
class UserRate {
  final String? fromCurrency;
  final num indexPrice;
  final num userPrice;
  final int? precision;

  const UserRate({
    this.fromCurrency,
    required this.indexPrice,
    required this.userPrice,
    this.precision,
  });
}
