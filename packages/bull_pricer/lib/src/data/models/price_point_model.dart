import 'package:bull_pricer/src/domain/entities/price_history_interval.dart';
import 'package:bull_pricer/src/domain/entities/price_point.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:primitives/primitives.dart';

final class PricePointModel {
  final BitcoinNetwork network;
  final SupportedCurrency currency;
  final PriceHistoryInterval interval;
  final DateTime time;
  final double fiatAmount;

  const PricePointModel({
    required this.network,
    required this.currency,
    required this.interval,
    required this.time,
    required this.fiatAmount,
  });

  PricePoint toEntity() =>
      PricePoint(currency: currency, fiatAmount: fiatAmount, time: time);
}
