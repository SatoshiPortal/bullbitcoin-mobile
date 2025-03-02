import 'package:decimal/decimal.dart';

abstract class BitcoinPriceRepository {
  Future<List<String>> getAvailableCurrencies();
  Future<Decimal> getBitcoinPrice(String currencyCode);
}
