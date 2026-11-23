import '../entities/order.dart';
import 'jurisdiction.dart';

/// What the exchange offers for one fiat currency.
///
/// The payout rails (recipient types) and funding rails (funding methods) of
/// the market join this record when they become types of their own.
final class Market {
  final FiatCurrency currency;
  final Jurisdiction jurisdiction;

  const Market({required this.currency, required this.jurisdiction});

  @override
  String toString() => 'Market(${currency.code})';
}
