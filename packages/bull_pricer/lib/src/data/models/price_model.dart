import 'package:bull_pricer/src/domain/entities/bitcoin_price.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:primitives/primitives.dart';

final class PriceModel {
  final BitcoinNetwork network;
  final SupportedCurrency currency;
  final double fiatAmount;
  final DateTime fetchedAt;

  const PriceModel({
    required this.network,
    required this.currency,
    required this.fiatAmount,
    required this.fetchedAt,
  });

  BitcoinPrice toEntity() => BitcoinPrice(
    currency: currency,
    fiatAmount: fiatAmount,
    fetchedAt: fetchedAt,
  );
}
